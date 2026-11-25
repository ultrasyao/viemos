import 'package:flutter/material.dart';
import 'ui.dart';

class AddTxnScreen extends StatelessWidget {
  const AddTxnScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Catat transaksi', style: kTitle),
          Expanded(
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 84,
                    height: 84,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: kOrange.withAlpha(28),
                      border: Border.all(color: kOrange.withAlpha(120), width: 2),
                    ),
                    child: const Icon(Icons.edit_outlined, color: kOrange, size: 36),
                  ),
                  const SizedBox(height: 18),
                  const Text('Ketuk tombol pensil di kanan bawah',
                      style: TextStyle(color: kMuted)),
                  const SizedBox(height: 4),
                  const Text('untuk mencatat transaksi', style: TextStyle(color: kMuted)),
                  const SizedBox(height: 120),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
