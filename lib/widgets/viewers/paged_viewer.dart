import 'package:flutter/material.dart';
import 'package:scrollable_positioned_list/scrollable_positioned_list.dart';
import '../../../models/document.dart';
import '../../widgets/page_card.dart'; // Usa PageCard

class PagedViewer extends StatelessWidget {
  final Document document;
  final String documentId;
  final String searchQuery;
  final TextAlign textAlign;
  final ItemScrollController bodyScrollController;
  final Function(int) onPageTap;

  const PagedViewer({
    super.key,
    required this.document,
    required this.documentId,
    required this.searchQuery,
    required this.textAlign,
    required this.bodyScrollController,
    required this.onPageTap,
  });

  @override
  Widget build(BuildContext context) {
    final pages = document.pages;
    if (pages.isEmpty) {
      return const Center(
        key: ValueKey('empty_pages'),
        child: Padding(
          padding: EdgeInsets.all(16.0),
          child: Text(
            'No pages disponibles',
            style: TextStyle(fontStyle: FontStyle.italic, color: Colors.grey),
          ),
        ),
      );
    }

    return ScrollablePositionedList.builder(
      reverse: false,
      physics: const ClampingScrollPhysics(),
      itemScrollController: bodyScrollController,
      itemCount: pages.length,
      padding: const EdgeInsets.all(8.0),
      itemBuilder: (context, index) {
        final page = pages[index];
        // pages[index] no debería ser null si el tipo es List<PageData>
        return Card(
          key: ValueKey('page_$index'),
          margin: const EdgeInsets.symmetric(vertical: 4.0),
          clipBehavior: Clip.hardEdge,
          child: InkWell(
            onTap: () => onPageTap(index),
            borderRadius: BorderRadius.circular(8.0),
            child: PageCard(
              key: ValueKey('content_$index'),
              page: page,
              documentId: documentId,
              index: index,
              searchQuery: searchQuery,
              textAlign: textAlign,
              continuousView: false,
            ),
          ),
        );
      },
    );
  }
}
