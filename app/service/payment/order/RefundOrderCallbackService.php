<?php

declare(strict_types=1);

namespace app\service\payment\order;

use app\common\base\BaseService;
use app\common\constant\PaymentPluginStatusConstant;
use app\common\interface\RefundNotifyInterface;
use app\exception\PaymentException;
use app\exception\ResourceNotFoundException;
use app\repository\payment\trade\PayOrderRepository;
use app\repository\payment\trade\RefundOrderRepository;
use app\service\payment\runtime\PaymentPluginManager;
use support\Log;
use support\Request;
use support\Response;
use Throwable;

/**
 * 独立退款通知处理服务。
 *
 * 退款通知按退款单定位插件，校验规范化结果后只推进 RefundLifecycleService，
 * 不调用支付通知或支付单生命周期。
 */
class RefundOrderCallbackService extends BaseService
{
    /**
     * 构造方法。
     *
     * @param RefundOrderRepository $refundOrderRepository 退款单仓库
     * @param PayOrderRepository $payOrderRepository 支付单仓库
     * @param PaymentPluginManager $paymentPluginManager 支付插件管理器
     * @param RefundLifecycleService $refundLifecycleService 退款生命周期服务
     */
    public function __construct(
        protected RefundOrderRepository $refundOrderRepository,
        protected PayOrderRepository $payOrderRepository,
        protected PaymentPluginManager $paymentPluginManager,
        protected RefundLifecycleService $refundLifecycleService
    ) {
    }

    /**
     * 处理渠道退款通知。
     *
     * @param string $refundNo 退款单号
     * @param Request $request 渠道通知请求
     * @return string|Response 插件协议 ACK
     */
    public function handlePluginCallback(string $refundNo, Request $request): string|Response
    {
        $refundOrder = $this->refundOrderRepository->findByRefundNo($refundNo);
        if (!$refundOrder) {
            throw new ResourceNotFoundException('退款单不存在', ['refund_no' => $refundNo]);
        }
        $payOrder = $this->payOrderRepository->findByPayNo((string) $refundOrder->pay_no);
        if (!$payOrder) {
            throw new ResourceNotFoundException('退款原支付单不存在', ['refund_no' => $refundNo]);
        }
        if ((int) $refundOrder->channel_id !== (int) $payOrder->channel_id) {
            throw new PaymentException('退款单与原支付单通道不一致', 40200, ['refund_no' => $refundNo]);
        }

        $plugin = null;
        try {
            $plugin = $this->paymentPluginManager->createByPayOrder($payOrder, true);
            if (!$plugin instanceof RefundNotifyInterface) {
                throw new PaymentException('当前支付插件不支持独立退款通知', 40200, ['refund_no' => $refundNo]);
            }
            $context = [
                'refund_no' => (string) $refundOrder->refund_no,
                'pay_no' => (string) $refundOrder->pay_no,
                'refund_amount' => (int) $refundOrder->refund_amount,
                'channel_id' => (int) $refundOrder->channel_id,
                'chan_refund_no' => (string) $refundOrder->channel_refund_no,
                'chan_trade_no' => (string) $payOrder->channel_trade_no,
                'amount' => (int) $payOrder->pay_amount,
            ];
            $result = PaymentPluginRefundResultValidator::make($plugin->refundNotify($request, $context))
                ->withScene('refund_status_result')
                ->withException(PaymentException::class)
                ->validate();
            $this->assertResultMatches($context, $result);
            $channelRefundNo = trim((string) ($result['chan_refund_no'] ?? ''));
            $status = (string) $result['status'];

            $this->refundLifecycleService->recordRefundProgress($refundNo, $channelRefundNo);

            if ($status === PaymentPluginStatusConstant::SUCCESS) {
                $this->refundLifecycleService->markRefundSuccess($refundNo, [
                    'channel_refund_no' => $channelRefundNo,
                ]);
            } elseif ($status === PaymentPluginStatusConstant::FAILED) {
                $this->refundLifecycleService->markRefundFailed($refundNo, [
                    'channel_refund_no' => $channelRefundNo,
                    'last_error' => trim((string) ($result['message'] ?? '渠道通知退款失败')),
                ]);
            }

            return $plugin->refundNotifySuccess();
        } catch (Throwable $e) {
            Log::warning(sprintf(
                '[RefundCallback] 退款通知处理失败 refund_no=%s error=%s',
                $refundNo,
                $e->getMessage()
            ));

            return $plugin instanceof RefundNotifyInterface ? $plugin->refundNotifyFail() : 'fail';
        }
    }

    /**
     * 校验插件退款通知结果与本地退款单是否一致。
     *
     * @param array<string, mixed> $context 本地退款上下文
     * @param array<string, mixed> $result 插件标准退款结果
     * @return void
     */
    private function assertResultMatches(array $context, array $result): void
    {
        foreach (['refund_no', 'pay_no'] as $field) {
            $expected = (string) $context[$field];
            $actual = trim((string) ($result[$field] ?? ''));
            if ($actual === '' || !hash_equals($expected, $actual)) {
                throw new PaymentException('退款通知返回 ' . $field . ' 不匹配', 40200, ['refund_no' => (string) $context['refund_no']]);
            }
        }
        if (!array_key_exists('refund_amount', $result)
            || (int) $result['refund_amount'] !== (int) $context['refund_amount']) {
            throw new PaymentException('退款通知返回金额不匹配', 40200, ['refund_no' => (string) $context['refund_no']]);
        }
        $channelRefundNo = trim((string) ($result['chan_refund_no'] ?? ''));
        $stored = trim((string) ($context['chan_refund_no'] ?? ''));
        if ($stored !== '' && $channelRefundNo !== '' && !hash_equals($stored, $channelRefundNo)) {
            throw new PaymentException('退款通知渠道退款号与退款单不匹配', 40200, ['refund_no' => (string) $context['refund_no']]);
        }
    }
}
