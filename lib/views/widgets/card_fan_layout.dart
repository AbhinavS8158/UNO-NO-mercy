import 'package:flutter/material.dart';
import '../../models/uno_card.dart';
import 'uno_card_widget.dart';

class CardFanLayout extends StatefulWidget {
  final List<UnoCard> cards;
  final UnoCard? selectedCard;
  final Function(UnoCard card) onCardSelected;
  final Function(UnoCard card) onCardPlayed;
  final UnoCard? topCard;
  final int pendingDrawCount;
  final bool isMyTurn;

  const CardFanLayout({
    super.key,
    required this.cards,
    this.selectedCard,
    required this.onCardSelected,
    required this.onCardPlayed,
    this.topCard,
    this.pendingDrawCount = 0,
    this.isMyTurn = true,
  });

  @override
  State<CardFanLayout> createState() => _CardFanLayoutState();
}

class _CardFanLayoutState extends State<CardFanLayout> {
  final ScrollController _scrollController = ScrollController();

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.cards.isEmpty) {
      return const SizedBox(
        height: 180,
        child: Center(
          child: Text(
            'കാർഡുകൾ ഒന്നുമില്ല!',
            style: TextStyle(color: Colors.white70),
          ),
        ),
      );
    }

    final cardCount = widget.cards.length;
    // Calculate overlap based on number of cards
    // If cards > 10, overlap more tightly to keep view clean
    final cardWidth = 105.0;
    final cardHeight = 155.0;
    final overlapSpacing = cardCount > 12 ? 38.0 : (cardCount > 7 ? 48.0 : 64.0);

    return SizedBox(
      height: 210,
      child: Center(
        child: SingleChildScrollView(
          controller: _scrollController,
          scrollDirection: Axis.horizontal,
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          child: SizedBox(
            width: cardWidth + (cardCount - 1) * overlapSpacing,
            height: 185,
            child: Stack(
              clipBehavior: Clip.none,
              children: List.generate(cardCount, (index) {
                final card = widget.cards[index];
                final isSelected = widget.selectedCard?.id == card.id;
                
                // Slight curved fan rotation
                final centerIndex = (cardCount - 1) / 2.0;
                final offsetFromCenter = index - centerIndex;
                final angle = (offsetFromCenter * 0.035).clamp(-0.25, 0.25);

                final isPlayable = widget.isMyTurn &&
                    (widget.topCard == null ||
                        card.canPlayOn(
                          widget.topCard!,
                          pendingDrawCount: widget.pendingDrawCount,
                        ));

                return Positioned(
                  left: index * overlapSpacing,
                  bottom: 0,
                  child: Transform.rotate(
                    angle: isSelected ? 0.0 : angle,
                    child: Opacity(
                      opacity: isPlayable ? 1.0 : 0.55,
                      child: UnoCardWidget(
                        card: card,
                        width: cardWidth,
                        height: cardHeight,
                        isSelected: isSelected,
                        isPlayable: isPlayable,
                        onTap: () {
                          if (!widget.isMyTurn) {
                            widget.onCardSelected(card);
                            return;
                          }
                          if (isSelected) {
                            // Double tap/click or tap when selected plays the card
                            widget.onCardPlayed(card);
                          } else {
                            widget.onCardSelected(card);
                          }
                        },
                      ),
                    ),
                  ),
                );
              }),
            ),
          ),
        ),
      ),
    );
  }
}
