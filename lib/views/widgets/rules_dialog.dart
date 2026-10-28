import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/theme/uno_colors.dart';

class RulesDialog extends StatelessWidget {
  const RulesDialog({super.key});

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: UnoColors.surfaceElevated,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 550, maxHeight: 600),
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            // Header
            Row(
              children: [
                const Icon(Icons.menu_book_rounded, color: Colors.orangeAccent, size: 28),
                const SizedBox(width: 10),
                Text(
                  'UNO NO MERCY - RULES',
                  style: GoogleFonts.bebasNeue(
                    color: Colors.white,
                    fontSize: 22,
                    letterSpacing: 1.5,
                  ),
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.close, color: Colors.white70),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const Divider(color: Colors.white24),

            // Scrollable Rules Content
            Expanded(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildSectionTitle('1. HOW TO START'),
                    _buildRuleText('• 2–6 കളിക്കാർ ഒന്നിച്ച് കളിക്കുന്നു.'),
                    _buildRuleText('• ഡെക്ക് ഷഫിൾ ചെയ്ത് ഓരോ കളിക്കാരനും 7 കാർഡുകൾ വീതം നൽകുന്നു.'),
                    _buildRuleText('• ബാക്കി കാർഡുകൾ ഡ്രോ പൈൽ (Draw Pile) ആയി വെക്കുന്നു.'),
                    _buildRuleText('• ടോപ്പ് കാർഡ് മാച്ച് ചെയ്ത് കളി ആരംഭിക്കുന്നു.'),

                    const SizedBox(height: 14),
                    _buildSectionTitle('2. HOW TO PLAY YOUR TURN'),
                    _buildRuleText('• നിങ്ങളുടെ ടേണിൽ ടോപ്പ് കാർഡിന്റെ കളർ, നമ്പർ, അല്ലെങ്കിൽ ചിഹ്നവുമായി മാച്ച് ചെയ്യുന്ന കാർഡ് കളിക്കുക.'),
                    _buildRuleText('• വൈൽഡ് കാർഡുകൾ ഏതു സമയത്തും കളിക്കാം.'),
                    _buildRuleText('• കളിക്കാൻ കാർഡ് ഇല്ലെങ്കിൽ ഡെക്കിൽ നിന്ന് ഒരു കാർഡ് ഡ്രോ ചെയ്യുക.'),

                    const SizedBox(height: 14),
                    _buildSectionTitle('3. SPECIAL CARDS'),
                    _buildRuleBadge('Single Skip ⊘', 'അടുത്ത കളിക്കാരന് മാത്രം ടേൺ നഷ്ടപ്പെടുന്നു (Single Skip).'),
                    _buildRuleBadge('Reverse ⇄', 'കളി നടക്കുന്ന ഡയറക്ഷൻ തിരിക്കുന്നു.'),
                    _buildRuleBadge('All Skip (Skip Everyone) ⊘', 'ബാക്കി എല്ലാവരെയും സ്കിപ്പ് ചെയ്ത് നിങ്ങൾക്ക് തന്നെ വീണ്ടും ടേൺ ലഭിക്കുന്നു (Double Skip ഇല്ല; Single Skip & All Skip മാത്രം).'),
                    _buildRuleBadge('Draw Cards (+2, +4, +6, +10)', 'അടുത്തയാൾ അത്രയും കാർഡുകൾ ഡ്രോ ചെയ്യണം (സ്റ്റാക്കിംഗ് നിയമം ബാധകം).'),
                    _buildRuleBadge('Discard All', 'ആ കളറിലുള്ള കയ്യിലെ എല്ലാ കാർഡുകളും ഒന്നിച്ചു കളയാം.'),
                    _buildRuleBadge('Wild Color Roulette 🎰', 'അടുത്ത കളിക്കാരൻ കളർ തിരഞ്ഞെടുത്ത് ആ കളർ കിട്ടുന്നതുവരെ കാർഡുകൾ ഡ്രോ ചെയ്യണം.'),
                    _buildRuleBadge('Wild Reverse Draw 4 ⇄ +4', 'ഡയറക്ഷൻ റിവേഴ്സ് ചെയ്യുകയും അടുത്തയാൾക്ക് +4 പെനാൽറ്റി നൽകുകയും ചെയ്യുന്നു.'),

                    const SizedBox(height: 14),
                    _buildSectionTitle('4. THREE IMPORTANT NO MERCY RULES'),
                    _buildRuleHighlight(
                      '⚡ Stacking Draw Cards',
                      'ആരെങ്കിലും +4 ഇട്ടാൽ, നിങ്ങൾക്ക് +4 അല്ലെങ്കിൽ അതിൽ കൂടുതൽ (+6, +10) സ്റ്റാക്ക് ചെയ്യാം. സഞ്ചിത പെനാൽറ്റി അടുത്തയാൾക്ക് കൈമാറുന്നു. ചെറിയ ഡ്രോ കാർഡ് വലിയ ഡ്രോ കാർഡിന് മുകളിൽ വെക്കാൻ കഴിയില്ല!',
                      Colors.orangeAccent,
                    ),
                    const SizedBox(height: 8),
                    _buildRuleHighlight(
                      '⇄ 7\'s Swap & 0\'s Pass',
                      '• 7 ഇട്ടാൽ ഇഷ്ടമുള്ള ഒരു കളിക്കാരനുമായി സ്വന്തം കാർഡുകൾ പരസ്പരം സ്വാപ്പ് ചെയ്യാം.\n• 0 ഇട്ടാൽ എല്ലാവരും തങ്ങളുടെ കാർഡുകൾ കളി നടക്കുന്ന ദിശയിൽ അടുത്തയാൾക്ക് കൈമാറുന്നു.',
                      Colors.blueAccent,
                    ),
                    const SizedBox(height: 8),
                    _buildRuleHighlight(
                      '☠️ The Mercy Rule (25 Cards Limit)',
                      'ഏതെങ്കിലും കളിക്കാരന്റെ കൈയിൽ 25 അല്ലെങ്കിൽ അതിൽ കൂടുതൽ കാർഡുകൾ എത്തിയാൽ അവർ കളിയിൽ നിന്ന് പൂർണ്ണമായി പുറത്താകും (Knocked Out)!',
                      Colors.redAccent,
                    ),

                    const SizedBox(height: 14),
                    _buildSectionTitle('5. HOW DO YOU WIN?'),
                    _buildRuleText('• കയ്യിലെ എല്ലാ കാർഡുകളും തീർത്ത് 0 കാർഡുകൾ ആക്കുന്ന ആദ്യ വ്യക്തി വിജയിക്കുന്നു.'),
                    _buildRuleText('• 1 കാർഡ് ശേഷിക്കുമ്പോൾ "CALL UNO!" വിളിക്കുക.'),
                    _buildRuleText('• മെർസി റൂൾ പ്രകാരം മറ്റുള്ളവർ പുറത്തായി അവസാനമായി ഒരാൾ മാത്രം അവശേഷിച്ചാൽ (Last Man Standing) അവർ വിജയിക്കും!'),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Text(
        title,
        style: GoogleFonts.rubik(
          color: UnoColors.yellow,
          fontWeight: FontWeight.w900,
          fontSize: 14,
          letterSpacing: 1,
        ),
      ),
    );
  }

  Widget _buildRuleText(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 3),
      child: Text(
        text,
        style: const TextStyle(color: Colors.white, fontSize: 13, height: 1.4),
      ),
    );
  }

  Widget _buildRuleBadge(String cardName, String desc) {
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.black26,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.white10),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: Colors.white12,
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              cardName,
              style: const TextStyle(
                color: UnoColors.yellow,
                fontWeight: FontWeight.bold,
                fontSize: 12,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              desc,
              style: const TextStyle(color: Colors.white70, fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRuleHighlight(String title, String desc, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withOpacity(0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: GoogleFonts.rubik(
              color: color,
              fontWeight: FontWeight.bold,
              fontSize: 13,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            desc,
            style: const TextStyle(color: Colors.white, fontSize: 12, height: 1.4),
          ),
        ],
      ),
    );
  }
}
