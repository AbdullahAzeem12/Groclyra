import 'dart:typed_data';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../../features/customer/orders/domain/entities/order_entity.dart';

class PdfInvoiceGenerator {
  static const String companyName = 'Groclyra Technologies Pakistan (Pvt) Ltd.';
  static const String companyNtn = 'PK-NTN-9482019-3';
  static const String companyGst = 'STRN-3277876123456';
  static const String companyAddress = 'Suite 401, Main Boulevard, Gulberg III, Lahore, Punjab';
  static const String helpline = '+92 (042) 111-GROC-99';

  /// Generates a high-fidelity, itemized PDF tax invoice for an order.
  static Future<Uint8List> generateInvoicePdf(OrderEntity order) async {
    final pdf = pw.Document();

    final fontRegular = await PdfGoogleFonts.poppinsRegular();
    final fontBold = await PdfGoogleFonts.poppinsBold();

    final dateFormatted = DateFormat('dd MMM yyyy, hh:mm a').format(order.createdAt);
    final totalItemsCount = order.subOrders.fold<int>(
      0,
      (sum, s) => sum + s.items.fold<int>(0, (iSum, it) => iSum + it.quantity),
    );

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        theme: pw.ThemeData.withFont(
          base: fontRegular,
          bold: fontBold,
        ),
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              // ── Header & Branding ───────────────────────────────────────────
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Row(
                        children: [
                          pw.Container(
                            padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            decoration: pw.BoxDecoration(
                              color: PdfColor.fromHex('#4F46E5'),
                              borderRadius: pw.BorderRadius.circular(6),
                            ),
                            child: pw.Text(
                              'GL',
                              style: const pw.TextStyle(
                                color: PdfColors.white,
                                fontWeight: pw.FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                          ),
                          pw.SizedBox(width: 8),
                          pw.Text(
                            'GROCLYRA',
                            style: pw.TextStyle(
                              fontSize: 22,
                              fontWeight: pw.FontWeight.bold,
                              color: PdfColor.fromHex('#0F172A'),
                              letterSpacing: 1.2,
                            ),
                          ),
                        ],
                      ),
                      pw.SizedBox(height: 4),
                      pw.Text(
                        'Luxury Tableware & Fresh Daily Grocery',
                        style: pw.TextStyle(fontSize: 10, color: PdfColor.fromHex('#64748B')),
                      ),
                      pw.SizedBox(height: 2),
                      pw.Text(
                        companyAddress,
                        style: pw.TextStyle(fontSize: 8.5, color: PdfColor.fromHex('#64748B')),
                      ),
                      pw.Text(
                        'NTN: $companyNtn  |  $companyGst',
                        style: pw.TextStyle(fontSize: 8.5, color: PdfColor.fromHex('#64748B')),
                      ),
                    ],
                  ),
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.end,
                    children: [
                      pw.Container(
                        padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: pw.BoxDecoration(
                          color: PdfColor.fromHex('#F1F5F9'),
                          borderRadius: pw.BorderRadius.circular(4),
                          border: pw.Border.all(color: PdfColor.fromHex('#CBD5E1')),
                        ),
                        child: pw.Text(
                          'OFFICIAL TAX INVOICE',
                          style: pw.TextStyle(
                            fontSize: 10,
                            fontWeight: pw.FontWeight.bold,
                            color: PdfColor.fromHex('#1E293B'),
                          ),
                        ),
                      ),
                      pw.SizedBox(height: 6),
                      pw.Text(
                        'Invoice #: ${order.orderNumber}',
                        style: const pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold),
                      ),
                      pw.Text(
                        'Date: $dateFormatted',
                        style: pw.TextStyle(fontSize: 9, color: PdfColor.fromHex('#64748B')),
                      ),
                      pw.Text(
                        'Payment: ${order.paymentMethod.title.toUpperCase()}',
                        style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold, color: PdfColor.fromHex('#059669')),
                      ),
                    ],
                  ),
                ],
              ),
              pw.SizedBox(height: 16),
              pw.Divider(color: PdfColor.fromHex('#E2E8F0'), thickness: 1),
              pw.SizedBox(height: 12),

              // ── Customer & Logistics Info ───────────────────────────────────
              pw.Row(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Expanded(
                    child: pw.Container(
                      padding: const pw.EdgeInsets.all(10),
                      decoration: pw.BoxDecoration(
                        color: PdfColor.fromHex('#F8FAFC'),
                        borderRadius: pw.BorderRadius.circular(6),
                      ),
                      child: pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Text(
                            'DELIVER TO (CUSTOMER)',
                            style: pw.TextStyle(fontSize: 8.5, fontWeight: pw.FontWeight.bold, color: PdfColor.fromHex('#475569')),
                          ),
                          pw.SizedBox(height: 4),
                          pw.Text(
                            order.customerName,
                            style: const pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold),
                          ),
                          pw.Text(
                            order.customerPhone.isNotEmpty ? order.customerPhone : 'Verified Account',
                            style: pw.TextStyle(fontSize: 9, color: PdfColor.fromHex('#334155')),
                          ),
                          pw.SizedBox(height: 2),
                          pw.Text(
                            order.deliveryAddress,
                            style: pw.TextStyle(fontSize: 9, color: PdfColor.fromHex('#475569')),
                          ),
                        ],
                      ),
                    ),
                  ),
                  pw.SizedBox(width: 16),
                  pw.Container(
                    width: 180,
                    padding: const pw.EdgeInsets.all(10),
                    decoration: pw.BoxDecoration(
                      color: PdfColor.fromHex('#F8FAFC'),
                      borderRadius: pw.BorderRadius.circular(6),
                    ),
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text(
                          'FULFILLMENT & SECURITY',
                          style: pw.TextStyle(fontSize: 8.5, fontWeight: pw.FontWeight.bold, color: PdfColor.fromHex('#475569')),
                        ),
                        pw.SizedBox(height: 4),
                        pw.Row(
                          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                          children: [
                            pw.Text('Status:', style: pw.TextStyle(fontSize: 9, color: PdfColor.fromHex('#64748B'))),
                            pw.Text(order.status.label, style: const pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold)),
                          ],
                        ),
                        pw.SizedBox(height: 2),
                        pw.Row(
                          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                          children: [
                            pw.Text('Handover PIN:', style: pw.TextStyle(fontSize: 9, color: PdfColor.fromHex('#64748B'))),
                            pw.Text('OTP: ${order.customerOtp}', style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold, color: PdfColor.fromHex('#D97706'))),
                          ],
                        ),
                        pw.SizedBox(height: 2),
                        pw.Row(
                          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                          children: [
                            pw.Text('Total Units:', style: pw.TextStyle(fontSize: 9, color: PdfColor.fromHex('#64748B'))),
                            pw.Text('$totalItemsCount Units', style: const pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold)),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              pw.SizedBox(height: 16),

              // ── Itemized Table ──────────────────────────────────────────────
              pw.Text(
                'ORDER ITEMS & VENDOR DETAILS',
                style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold, color: PdfColor.fromHex('#475569')),
              ),
              pw.SizedBox(height: 6),
              pw.Table(
                border: pw.TableBorder(
                  horizontalInside: pw.BorderSide(color: PdfColor.fromHex('#F1F5F9'), width: 1),
                  bottom: pw.BorderSide(color: PdfColor.fromHex('#E2E8F0'), width: 1),
                ),
                columnWidths: {
                  0: const pw.FlexColumnWidth(4.5),
                  1: const pw.FlexColumnWidth(2.5),
                  2: const pw.FlexColumnWidth(1.2),
                  3: const pw.FlexColumnWidth(1.8),
                  4: const pw.FlexColumnWidth(2.0),
                },
                children: [
                  // Table Header
                  pw.TableRow(
                    decoration: pw.BoxDecoration(color: PdfColor.fromHex('#F8FAFC')),
                    children: [
                      _buildHeaderCell('Description / Item Name'),
                      _buildHeaderCell('Partner Merchant'),
                      _buildHeaderCell('Qty', align: pw.TextAlign.center),
                      _buildHeaderCell('Unit (Rs.)', align: pw.TextAlign.right),
                      _buildHeaderCell('Total (Rs.)', align: pw.TextAlign.right),
                    ],
                  ),
                  // Table Rows
                  ...order.subOrders.expand((sub) {
                    return sub.items.map((it) {
                      final variantName = it.selectedVariant?.name;
                      return pw.TableRow(
                        children: [
                          pw.Padding(
                            padding: const pw.EdgeInsets.symmetric(vertical: 6, horizontal: 6),
                            child: pw.Column(
                              crossAxisAlignment: pw.CrossAxisAlignment.start,
                              children: [
                                pw.Text(it.product.title, style: const pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold)),
                                if (variantName != null && variantName.isNotEmpty)
                                  pw.Text('Variant: $variantName', style: pw.TextStyle(fontSize: 7.5, color: PdfColor.fromHex('#64748B'))),
                              ],
                            ),
                          ),
                          pw.Padding(
                            padding: const pw.EdgeInsets.symmetric(vertical: 6, horizontal: 6),
                            child: pw.Text(sub.sellerName, style: pw.TextStyle(fontSize: 8.5, color: PdfColor.fromHex('#475569'))),
                          ),
                          pw.Padding(
                            padding: const pw.EdgeInsets.symmetric(vertical: 6, horizontal: 6),
                            child: pw.Text('${it.quantity}', textAlign: pw.TextAlign.center, style: const pw.TextStyle(fontSize: 9)),
                          ),
                          pw.Padding(
                            padding: const pw.EdgeInsets.symmetric(vertical: 6, horizontal: 6),
                            child: pw.Text(it.unitPrice.toStringAsFixed(0), textAlign: pw.TextAlign.right, style: const pw.TextStyle(fontSize: 9)),
                          ),
                          pw.Padding(
                            padding: const pw.EdgeInsets.symmetric(vertical: 6, horizontal: 6),
                            child: pw.Text(it.totalPrice.toStringAsFixed(0), textAlign: pw.TextAlign.right, style: const pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold)),
                          ),
                        ],
                      );
                    });
                  }),
                ],
              ),
              pw.SizedBox(height: 12),

              // ── Financial Summary & QR Verification ─────────────────────────
              pw.Row(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  // Verification Barcode & Terms
                  pw.Expanded(
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.BarcodeWidget(
                          barcode: pw.Barcode.code128(),
                          data: order.orderNumber,
                          width: 140,
                          height: 38,
                          drawText: false,
                        ),
                        pw.SizedBox(height: 4),
                        pw.Text(
                          'Scan for instant delivery verification & electronic claims.',
                          style: pw.TextStyle(fontSize: 7.5, color: PdfColor.fromHex('#94A3B8')),
                        ),
                        pw.SizedBox(height: 6),
                        pw.Text(
                          '• Fragile Tableware Guarantee: Report breakage within 24h with unboxing video.\n'
                          '• Return & Refund queries: support@groclyra.app or $helpline\n'
                          '• Computer generated tax invoice. No physical signature required.',
                          style: pw.TextStyle(fontSize: 7.5, color: PdfColor.fromHex('#64748B'), height: 1.3),
                        ),
                      ],
                    ),
                  ),
                  pw.SizedBox(width: 24),
                  // Calculation Totals
                  pw.Container(
                    width: 200,
                    padding: const pw.EdgeInsets.all(10),
                    decoration: pw.BoxDecoration(
                      color: PdfColor.fromHex('#F8FAFC'),
                      borderRadius: pw.BorderRadius.circular(6),
                      border: pw.Border.all(color: PdfColor.fromHex('#E2E8F0')),
                    ),
                    child: pw.Column(
                      children: [
                        _buildSummaryLine('Subtotal', 'Rs. ${order.subtotal.toStringAsFixed(0)}'),
                        _buildSummaryLine('Delivery Fee', 'Rs. ${order.totalShippingFee.toStringAsFixed(0)}'),
                        if (order.discountAmount > 0)
                          _buildSummaryLine('Discount Promo', '-Rs. ${order.discountAmount.toStringAsFixed(0)}', isDiscount: true),
                        pw.Divider(color: PdfColor.fromHex('#CBD5E1'), thickness: 0.8),
                        pw.Row(
                          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                          children: [
                            pw.Text('Grand Total', style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold, color: PdfColor.fromHex('#0F172A'))),
                            pw.Text('Rs. ${order.totalAmount.toStringAsFixed(0)}', style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold, color: PdfColor.fromHex('#4F46E5'))),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              pw.Spacer(),

              // ── Footer ──────────────────────────────────────────────────────
              pw.Divider(color: PdfColor.fromHex('#E2E8F0'), thickness: 1),
              pw.SizedBox(height: 4),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text('Groclyra Unified Marketplace • Powered by SQLite Real-time', style: pw.TextStyle(fontSize: 7.5, color: PdfColor.fromHex('#94A3B8'))),
                  pw.Text('Thank you for shopping with Groclyra Pakistan', style: pw.TextStyle(fontSize: 7.5, color: PdfColor.fromHex('#94A3B8'))),
                ],
              ),
            ],
          );
        },
      ),
    );

    return pdf.save();
  }

  static pw.Widget _buildHeaderCell(String text, {pw.TextAlign align = pw.TextAlign.left}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 6, horizontal: 6),
      child: pw.Text(
        text,
        textAlign: align,
        style: pw.TextStyle(
          fontSize: 8.5,
          fontWeight: pw.FontWeight.bold,
          color: PdfColor.fromHex('#334155'),
        ),
      ),
    );
  }

  static pw.Widget _buildSummaryLine(String label, String value, {bool isDiscount = false}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 2.5),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(label, style: pw.TextStyle(fontSize: 9, color: PdfColor.fromHex('#64748B'))),
          pw.Text(
            value,
            style: pw.TextStyle(
              fontSize: 9,
              fontWeight: pw.FontWeight.bold,
              color: isDiscount ? PdfColor.fromHex('#DC2626') : PdfColor.fromHex('#1E293B'),
            ),
          ),
        ],
      ),
    );
  }

  /// Direct print layout dialog
  static Future<void> printInvoice(OrderEntity order) async {
    final pdfBytes = await generateInvoicePdf(order);
    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => pdfBytes,
      name: 'Invoice_${order.orderNumber}.pdf',
    );
  }

  /// Native share PDF file across WhatsApp, Email, or Files
  static Future<void> shareInvoice(OrderEntity order) async {
    final pdfBytes = await generateInvoicePdf(order);
    await Printing.sharePdf(
      bytes: pdfBytes,
      filename: 'Invoice_${order.orderNumber}.pdf',
    );
  }
}
