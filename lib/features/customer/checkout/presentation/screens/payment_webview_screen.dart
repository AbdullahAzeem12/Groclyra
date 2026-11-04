import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:groclyra/core/services/payment_service.dart';
import 'package:groclyra/core/services/payfast_gateway.dart';
import 'package:webview_flutter/webview_flutter.dart';

/// Secure in-app gateway browser.
///
/// Upgraded (full implementation):
///  • Loads an AUTO-SUBMITTING form (JazzCash hosted checkout / Easypaisa
///    Index.jsf) — the gateway page itself is rendered from the merchant's
///    real credentials.
///  • Intercepts the return/callback redirect and — for JazzCash — verifies
///    `pp_SecureHash` on the appended query parameters BEFORE trusting any
///    "paid" claim. For Easypaisa (async MA / OTC transactions) it polls the
///    official Transaction Status Inquiry until the gateway settles.
///  • Falls back cleanly (network loss, non-JSON responses, closed gateway).
class PaymentWebviewScreen extends ConsumerStatefulWidget {
  final String checkoutHtml; // auto-submitting form (hosted checkout)
  final String orderId;
  final String txnRefNo;
  final PaymentGateway gateway;

  /// PayFast callbacks carry an MD5 over (merchant:name:amount:order) — the
  /// expected amount is needed locally to re-verify it.
  final double? payFastAmount;

  const PaymentWebviewScreen({
    super.key,
    required this.checkoutHtml,
    required this.orderId,
    required this.txnRefNo,
    required this.gateway,
    this.payFastAmount,
  });

  @override
  ConsumerState<PaymentWebviewScreen> createState() =>
      _PaymentWebviewScreenState();
}

class _PaymentWebviewScreenState extends ConsumerState<PaymentWebviewScreen>
    with WidgetsBindingObserver {
  late final WebViewController _controller;
  bool _isLoading = true;
  bool _hasVerified = false; // guard against double verification
  bool _verifyingDialogOpen = false;
  String? _failureBanner;

  static bool _isGatewayReturn(String url) =>
      url.contains('groclyra.app/payment/') || url.startsWith('groclyra://payment');
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setUserAgent('Groclyra/1.0 (+https://groclyra.app)')
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (String url) {
            if (mounted) setState(() => _isLoading = true);
          },
          onPageFinished: (String url) {
            if (mounted) setState(() => _isLoading = false);
            if (_isGatewayReturn(url)) {
              _handleGatewayReturn(url);
            }
          },
          onNavigationRequest: (NavigationRequest request) {
            if (_isGatewayReturn(request.url)) {
              _handleGatewayReturn(request.url);
              return NavigationDecision.prevent;
            }
            return NavigationDecision.navigate;
          },
          onWebResourceError: (error) {
            if (mounted) {
              setState(() {
                _isLoading = false;
                _failureBanner =
                    'The gateway page could not load. Check your connection and try again.';
              });
            }
          },
        ),
      )
      ..loadHtmlString(widget.checkoutHtml, baseUrl: 'https://groclyra.app/');
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Customer may leave the app to confirm an Easypaisa MPIN push; when
    // they come back, proactively check the gateway status once.
    if (state == AppLifecycleState.resumed &&
        !_hasVerified &&
        widget.gateway == PaymentGateway.easypaisa &&
        mounted) {
      _startPolling();
    }
  }

  // ───────────────────────────────────────────────────────────────────────────
  // GATEWAY RETURN HANDLING
  // ───────────────────────────────────────────────────────────────────────────

  Future<void> _handleGatewayReturn(String url) async {
    if (!mounted || _hasVerified) return;
    _hasVerified = true;

    _showVerifyingDialog();

    try {
      if (widget.gateway == PaymentGateway.payFast) {
        final params = Uri.tryParse(url)?.queryParameters ?? const {};
        final result = await PayFastGateway.verifyAndSettle(
          orderId: widget.orderId,
          txnRefNo: widget.txnRefNo,
          amount: widget.payFastAmount ?? 0.0,
          returnParams: params,
        );
        _settle(result);
      } else if (widget.gateway == PaymentGateway.jazzCash) {
        final params = Uri.tryParse(url)?.queryParameters ?? const {};
        final result = await PaymentService.verifyJazzCashRedirect(
          txnRefNo: widget.txnRefNo,
          orderId: widget.orderId,
          returnParams: params,
        );
        _settle(result);
      } else {
        final result = await PaymentService.pollEasypaisaUntilSettled(
          orderId: widget.orderId,
          txnRefNo: widget.txnRefNo,
          attempts: 12,
        );
        _settle(result);
      }
    } catch (e) {
      _settle(
        PaymentVerifyResult(
          paid: false,
          txnRefNo: widget.txnRefNo,
          responseMessage: e.toString(),
        ),
      );
    }
  }

  Future<void> _startPolling() async {
    if (_hasVerified) return;
    _hasVerified = true;

    _showVerifyingDialog();
    final result = await PaymentService.pollEasypaisaUntilSettled(
      orderId: widget.orderId,
      txnRefNo: widget.txnRefNo,
      attempts: 12,
    );
    _settle(result);
  }

  // ───────────────────────────────────────────────────────────────────────────
  // RESULT FUNNEL
  // ───────────────────────────────────────────────────────────────────────────

  void _settle(PaymentVerifyResult result) {
    if (!mounted) return;
    _popVerifyingDialog();
    if (result.paid) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
              'Payment Successful!${result.responseMessage != null ? ' — ${result.responseMessage}' : ''}'),
          backgroundColor: Colors.green,
        ),
      );
      Navigator.of(context).pop(true); // success to checkout
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Payment not completed: ${result.responseMessage}'),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 5),
        ),
      );
      // 'PENDING' means the async gateway has not rendered a final decision —
      // signal it so the checkout keeps the order alive for later completion.
      Navigator.of(context).pop(result.responseCode == 'PENDING' ? 'pending' : false);
    }
  }

  void _showVerifyingDialog() {
    if (!mounted || _verifyingDialogOpen) return;
    _verifyingDialogOpen = true;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => const PopScope(
        canPop: false,
        child: Center(
          child: Card(
            child: Padding(
              padding: EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('Verifying with the gateway…'),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _popVerifyingDialog() {
    if (!_verifyingDialogOpen) return;
    _verifyingDialogOpen = false;
    Navigator.of(context, rootNavigator: true).pop();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Secure Checkout'),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () {
            if (_verifyingDialogOpen) return; // don't cancel mid-verification
            Navigator.of(context).pop(false);
          },
        ),
      ),
      body: Stack(
        children: [
          WebViewWidget(controller: _controller),
          if (_isLoading)
            const Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 12),
                  Text('Connecting to secure gateway…'),
                ],
              ),
            ),
          if (_failureBanner != null)
            Positioned(
              left: 16,
              right: 16,
              bottom: 16,
              child: Card(
                color: Colors.orange.shade50,
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    children: [
                      const Icon(Icons.wifi_off_rounded, color: Colors.orange),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          _failureBanner!,
                          style: const TextStyle(fontSize: 12.5),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
