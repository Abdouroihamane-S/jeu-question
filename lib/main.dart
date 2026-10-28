import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'firebase_options.dart';

// ============================================================
//  THÈME
// ============================================================
const kBgTop = Color(0xFF0B1020);
const kBgBottom = Color(0xFF1B1446);
const kGold = Color(0xFFFFC857);

extension Alpha on Color {
  Color fade(double o) => withAlpha((o * 255).round());
}

// ============================================================
//  SCORE SAUVEGARDÉ
// ============================================================
class Stats {
  static int best = 0;
  static int money = 0;
  static int stock5050 = 0;
  static int stockTime = 0;
  static int stockSkip = 0;
  static int bestSurvival = 0;
  static Set<String> badges = {};
  static String pseudo = '';

  static Future<void> load() async {
    try {
      final p = await SharedPreferences.getInstance();
      best = p.getInt('best') ?? 0;
      money = p.getInt('money') ?? 0;
      stock5050 = p.getInt('stock5050') ?? 0;
      stockTime = p.getInt('stockTime') ?? 0;
      stockSkip = p.getInt('stockSkip') ?? 0;
      bestSurvival = p.getInt('bestSurvival') ?? 0;
      badges = (p.getStringList('badges') ?? <String>[]).toSet();
      pseudo = p.getString('pseudo') ?? '';
    } catch (_) {}
  }

  static Future<void> savePseudo(String v) async {
    pseudo = v;
    try {
      final p = await SharedPreferences.getInstance();
      await p.setString('pseudo', v);
    } catch (_) {}
  }

  static Future<void> save() async {
    try {
      final p = await SharedPreferences.getInstance();
      await p.setInt('best', best);
      await p.setInt('money', money);
      await p.setInt('stock5050', stock5050);
      await p.setInt('stockTime', stockTime);
      await p.setInt('stockSkip', stockSkip);
      await p.setInt('bestSurvival', bestSurvival);
      await p.setStringList('badges', badges.toList());
    } catch (_) {}
  }
}

// Gain en FCFA pour une bonne réponse, selon le numéro de la question.
const List<int> kLadder = [
  100, 200, 300, 500, 1000, 2000, 4000, 8000, 16000, 32000
];

String fcfa(int v) {
  final s = v.toString();
  final b = StringBuffer();
  for (var i = 0; i < s.length; i++) {
    if (i > 0 && (s.length - i) % 3 == 0) b.write(' ');
    b.write(s[i]);
  }
  return '$b FCFA';
}

String rankName(int m) {
  if (m >= 500000) return '👑 Champion';
  if (m >= 150000) return '🏆 Expert';
  if (m >= 40000) return '🎓 Initié';
  return '🌱 Novice';
}

class Achievement {
  final String id, emoji, name, desc;
  const Achievement(this.id, this.emoji, this.name, this.desc);
}

const List<Achievement> kAchievements = [
  Achievement('first', '🎮', 'Première partie', 'Termine ta première partie'),
  Achievement('perfect', '💯', 'Partie parfaite', '10 bonnes réponses sur 10'),
  Achievement('streak5', '🔥', 'En feu', 'Enchaîne 5 bonnes réponses'),
  Achievement(
      'survivor', '🛡️', 'Survivant', '15 bonnes réponses en mode survie'),
  Achievement(
      'rich', '💰', 'Gros portefeuille', 'Atteins 100 000 FCFA de cagnotte'),
  Achievement('shopper', '🛒', 'Premier achat', 'Achète un joker à la boutique'),
];

/// Débloque les succès demandés et renvoie ceux qui sont nouveaux.
List<Achievement> unlockAchievements(Set<String> ids) {
  final fresh = <Achievement>[];
  for (final a in kAchievements) {
    if (ids.contains(a.id) && !Stats.badges.contains(a.id)) {
      Stats.badges.add(a.id);
      fresh.add(a);
    }
  }
  if (fresh.isNotEmpty) Stats.save();
  return fresh;
}

Future<void> shareWhatsApp(int score, int money) async {
  final msg =
      '🏆 J’ai fait $score points et gagné ${fcfa(money)} au quiz « Questions pour un champion » ! '
      'Peux-tu me battre ? 👉 https://abdouroihamane-s.github.io/jeu-question/';
  try {
    await launchUrl(
      Uri.parse('https://wa.me/?text=${Uri.encodeComponent(msg)}'),
      mode: LaunchMode.externalApplication,
    );
  } catch (_) {}
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform);
  } catch (_) {}
  await Stats.load();
  runApp(const QuizApp());
}

Future<void> ensurePseudo(BuildContext context) async {
  if (Stats.pseudo.isNotEmpty) return;
  final c = TextEditingController();
  final v = await showDialog<String>(
    context: context,
    barrierDismissible: false,
    builder: (ctx) => AlertDialog(
      title: const Text('Ton pseudo'),
      content: TextField(
        controller: c,
        maxLength: 20,
        autofocus: true,
        decoration: const InputDecoration(hintText: 'Ex : Abdou'),
        onSubmitted: (_) {
          final t = c.text.trim();
          if (t.isNotEmpty) Navigator.pop(ctx, t);
        },
      ),
      actions: [
        TextButton(
          onPressed: () {
            final t = c.text.trim();
            if (t.isNotEmpty) Navigator.pop(ctx, t);
          },
          child: const Text('OK'),
        ),
      ],
    ),
  );
  if (v != null) await Stats.savePseudo(v);
}

class QuizApp extends StatelessWidget {
  const QuizApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Questions pour un champion',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        colorSchemeSeed: const Color(0xFF6D28D9),
        scaffoldBackgroundColor: kBgTop,
      ),
      home: const MenuPage(),
    );
  }
}

// ============================================================
//  DONNÉES
// ============================================================
class Question {
  final String text;
  final String correct;
  final List<String> wrong;
  Question(this.text, this.correct, this.wrong);
}

class Category {
  final String name;
  final IconData icon;
  final Color color;
  final List<Question> questions;
  Category(this.name, this.icon, this.color, this.questions);
}

/// Question préparée pour une partie (réponses mélangées).
class Round {
  final String text;
  final List<String> options;
  final int answer;
  Round(this.text, this.options, this.answer);

  factory Round.from(Question q) {
    final opts = [q.correct, ...q.wrong]..shuffle();
    return Round(q.text, opts, opts.indexOf(q.correct));
  }
}

final List<Category> categories = [
  Category('Culture générale', Icons.lightbulb_rounded, const Color(0xFFFFB020), [
    Question('Combien de joueurs une équipe de football a-t-elle sur le terrain ?',
        '11', ['9', '10', '12']),
    Question('Qui a peint la Joconde ?', 'Léonard de Vinci',
        ['Michel-Ange', 'Picasso', 'Van Gogh']),
    Question('Quelle langue compte le plus de locuteurs natifs ?', 'Le mandarin',
        ['L\'anglais', 'L\'espagnol', 'Le français']),
    Question('Combien de couleurs compte l\'arc-en-ciel ?', '7', ['5', '6', '8']),
    Question('Quel est le plus grand océan du monde ?', 'L\'océan Pacifique',
        ['L\'océan Atlantique', 'L\'océan Indien', 'L\'océan Arctique']),
    Question('Dans quel sport utilise-t-on un volant ?', 'Le badminton',
        ['Le tennis', 'Le squash', 'Le golf']),
    Question('Combien de touches compte un piano standard ?', '88',
        ['66', '76', '96']),
    Question('Qui a écrit « Les Misérables » ?', 'Victor Hugo',
        ['Émile Zola', 'Molière', 'Alexandre Dumas']),
  ]),
  Category('Géographie', Icons.public_rounded, const Color(0xFF38BDF8), [
    Question('Quelle est la capitale du Japon ?', 'Tokyo',
        ['Kyoto', 'Osaka', 'Séoul']),
    Question('Quel est le plus long fleuve d\'Afrique ?', 'Le Nil',
        ['Le Congo', 'Le Niger', 'Le Zambèze']),
    Question('Quel est le pays le plus vaste du monde ?', 'La Russie',
        ['Le Canada', 'La Chine', 'Les États-Unis']),
    Question('Quelle est la capitale du Brésil ?', 'Brasilia',
        ['Rio de Janeiro', 'São Paulo', 'Salvador']),
    Question('Quel grand désert couvre le nord de l\'Afrique ?', 'Le Sahara',
        ['Le Kalahari', 'Le Gobi', 'Le Namib']),
    Question('Quel est le continent le plus peuplé ?', 'L\'Asie',
        ['L\'Afrique', 'L\'Europe', 'L\'Amérique']),
    Question('Quelle est la capitale de l\'Australie ?', 'Canberra',
        ['Sydney', 'Melbourne', 'Perth']),
    Question('Quelle est la plus haute montagne du monde ?', 'L\'Everest',
        ['Le K2', 'Le Mont Blanc', 'Le Kilimandjaro']),
  ]),
  Category('Histoire', Icons.account_balance_rounded, const Color(0xFFFB7185), [
    Question('En quelle année a eu lieu la Révolution française ?', '1789',
        ['1769', '1799', '1815']),
    Question('Qui fut le premier homme à marcher sur la Lune ?', 'Neil Armstrong',
        ['Buzz Aldrin', 'Youri Gagarine', 'John Glenn']),
    Question('En quelle année s\'est terminée la Seconde Guerre mondiale ?', '1945',
        ['1918', '1939', '1950']),
    Question('Qui fut le premier président des États-Unis ?', 'George Washington',
        ['Abraham Lincoln', 'Thomas Jefferson', 'John Adams']),
    Question('Quel peuple a construit les pyramides de Gizeh ?', 'Les Égyptiens',
        ['Les Romains', 'Les Grecs', 'Les Mayas']),
    Question('En quelle année Nelson Mandela a-t-il été libéré de prison ?', '1990',
        ['1980', '1994', '1985']),
    Question('En quelle année Christophe Colomb atteint-il l\'Amérique ?', '1492',
        ['1453', '1519', '1607']),
    Question('En quelle année le mur de Berlin est-il tombé ?', '1989',
        ['1961', '1975', '1991']),
  ]),
  Category('Sciences', Icons.science_rounded, const Color(0xFF34D399), [
    Question('Quel est le symbole chimique de l\'eau ?', 'H₂O',
        ['CO₂', 'O₂', 'NaCl']),
    Question('Quelle planète est surnommée la planète rouge ?', 'Mars',
        ['Vénus', 'Jupiter', 'Mercure']),
    Question('Combien d\'os compte le corps d\'un adulte ?', '206',
        ['106', '256', '312']),
    Question('Quel gaz les plantes absorbent-elles pour la photosynthèse ?',
        'Le dioxyde de carbone', ['L\'oxygène', 'L\'azote', 'L\'hélium']),
    Question('Quel est le plus grand organe du corps humain ?', 'La peau',
        ['Le foie', 'Le cœur', 'Les poumons']),
    Question('Quelle est la vitesse de la lumière (environ) ?', '300 000 km/s',
        ['30 000 km/s', '3 000 km/s', '3 millions km/s']),
    Question('Quel est le symbole chimique de l\'or ?', 'Au',
        ['Or', 'Ag', 'Go']),
    Question('Quelle planète est la plus proche du Soleil ?', 'Mercure',
        ['Vénus', 'Mars', 'La Terre']),
  ]),
  Category('Sénégal & Afrique', Icons.flag_rounded, const Color(0xFF2DD4BF), [
    Question('Quelle est la capitale du Sénégal ?', 'Dakar',
        ['Saint-Louis', 'Thiès', 'Touba']),
    Question('Qui fut le premier président du Sénégal ?', 'Léopold Sédar Senghor',
        ['Abdou Diouf', 'Abdoulaye Wade', 'Mamadou Dia']),
    Question('En quelle année le Sénégal est-il devenu indépendant ?', '1960',
        ['1958', '1962', '1956']),
    Question('Comment s\'appelle le célèbre lac rose du Sénégal ?', 'Le lac Retba',
        ['Le lac Tchad', 'Le lac Victoria', 'Le lac de Guiers']),
    Question('Quelle île près de Dakar est classée à l\'UNESCO et liée à la mémoire de la traite ?',
        'Gorée', ['Carabane', 'Saint-Louis', 'Ngor']),
    Question('Quel monument inauguré en 2010 domine Dakar ?',
        'Le Monument de la Renaissance africaine',
        ['La Tour Eiffel', 'La Grande Mosquée', 'Le Phare des Mamelles']),
    Question('Quel est le plat national du Sénégal ?', 'Le thiéboudienne',
        ['Le mafé', 'Le yassa', 'Le couscous']),
    Question('Quel est le pays le plus peuplé d\'Afrique ?', 'Le Nigeria',
        ['L\'Éthiopie', 'L\'Égypte', 'L\'Afrique du Sud']),
  ]),
  Category('Informatique', Icons.computer_rounded, const Color(0xFF818CF8), [
    Question('Que signifie « HTML » ?', 'HyperText Markup Language',
        ['HighText Machine Language', 'HyperTool Multi Language', 'Home Text Markup Language']),
    Question('Quel composant est surnommé le « cerveau » de l\'ordinateur ?',
        'Le processeur (CPU)',
        ['Le disque dur', 'La carte graphique', 'L\'alimentation']),
    Question('Combien de bits contient un octet ?', '8', ['4', '16', '32']),
    Question('Que signifie « RAM » ?', 'Mémoire vive',
        ['Mémoire morte', 'Disque dur', 'Carte mère']),
    Question('Quel langage de programmation est utilisé par Flutter ?', 'Dart',
        ['Kotlin', 'Swift', 'Ruby']),
    Question('Qui a créé le noyau Linux ?', 'Linus Torvalds',
        ['Bill Gates', 'Steve Jobs', 'Mark Zuckerberg']),
    Question('Que signifie le « S » de HTTPS ?', 'Secure (sécurisé)',
        ['Standard', 'Server', 'Speed']),
    Question('Qui a cofondé Microsoft avec Paul Allen ?', 'Bill Gates',
        ['Steve Jobs', 'Elon Musk', 'Larry Page']),
    Question('Quel langage sert principalement à mettre en forme les pages web ?',
        'CSS', ['SQL', 'Python', 'Java']),
    Question('Quel langage sert à interroger les bases de données ?', 'SQL',
        ['CSS', 'HTML', 'C++']),
  ]),
];

// ============================================================
//  COMPOSANTS COMMUNS
// ============================================================

/// Fond dégradé avec halos lumineux, contenu centré (max 520 px de large).
class AppBackground extends StatelessWidget {
  final Widget child;
  const AppBackground({super.key, required this.child});

  Widget _glow(Color c, double size) => Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(colors: [c.fade(0.35), c.fade(0)]),
        ),
      );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [kBgTop, kBgBottom],
          ),
        ),
        child: Stack(
          fit: StackFit.expand,
          children: [
            Positioned(
                top: -80, right: -60, child: _glow(const Color(0xFF6D28D9), 280)),
            Positioned(
                bottom: -100,
                left: -80,
                child: _glow(const Color(0xFF0EA5E9), 320)),
            SafeArea(
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 520),
                  child: child,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Apparition en fondu + glissement.
class FadeSlide extends StatelessWidget {
  final int order;
  final Widget child;
  const FadeSlide({super.key, required this.order, required this.child});

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: Duration(milliseconds: 450 + order * 120),
      curve: Curves.easeOutCubic,
      builder: (context, v, ch) => Opacity(
        opacity: v.clamp(0.0, 1.0),
        child: Transform.translate(offset: Offset(0, 28 * (1 - v)), child: ch),
      ),
      child: child,
    );
  }
}

class CategoryCard extends StatelessWidget {
  final String name;
  final String subtitle;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const CategoryCard({
    super.key,
    required this.name,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: Colors.transparent,
        child: Ink(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [color.fade(0.30), color.fade(0.08)],
            ),
            border: Border.all(color: color.fade(0.55)),
            boxShadow: [
              BoxShadow(
                  color: color.fade(0.18), blurRadius: 18, offset: const Offset(0, 8)),
            ],
          ),
          child: InkWell(
            borderRadius: BorderRadius.circular(20),
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Container(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(16),
                      gradient:
                          LinearGradient(colors: [color, color.fade(0.65)]),
                    ),
                    child: Icon(icon, color: Colors.white, size: 28),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(name,
                            style: const TextStyle(
                                fontSize: 18, fontWeight: FontWeight.w700)),
                        const SizedBox(height: 2),
                        Text(subtitle,
                            style: TextStyle(
                                fontSize: 13, color: Colors.white.fade(0.6))),
                      ],
                    ),
                  ),
                  Icon(Icons.arrow_forward_ios_rounded,
                      size: 16, color: Colors.white.fade(0.5)),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ============================================================
//  MENU
// ============================================================
class MenuPage extends StatefulWidget {
  const MenuPage({super.key});

  @override
  State<MenuPage> createState() => _MenuPageState();
}

class _MenuPageState extends State<MenuPage> {
  Future<void> _start(String title, Color color, List<Question> pool,
      {bool survival = false}) async {
    await ensurePseudo(context);
    if (Stats.pseudo.isEmpty || !mounted) return;
    Navigator.push(
      context,
      MaterialPageRoute(
          builder: (_) => QuizPage(
              title: title, color: color, pool: pool, survival: survival)),
    ).then((_) => setState(() {}));
  }

  Widget _menuButton(String label, IconData icon, Widget Function() page) {
    return OutlinedButton.icon(
      onPressed: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => page()),
      ).then((_) => setState(() {})),
      icon: Icon(icon, color: kGold),
      label: Text(label),
      style: OutlinedButton.styleFrom(
        minimumSize: const Size.fromHeight(50),
        side: BorderSide(color: Colors.white.fade(0.3)),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
      ),
    );
  }

  Widget _header() {
    return Column(
      children: [
        Container(
          width: 96,
          height: 96,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [kGold, Color(0xFFFF8A3D)],
            ),
            boxShadow: [
              BoxShadow(color: kGold.fade(0.5), blurRadius: 32, spreadRadius: 2),
            ],
          ),
          child: const Icon(Icons.emoji_events_rounded,
              size: 52, color: Color(0xFF3B2300)),
        ),
        const SizedBox(height: 18),
        ShaderMask(
          shaderCallback: (r) => const LinearGradient(
            colors: [Colors.white, kGold],
          ).createShader(r),
          child: const Text(
            'Questions pour\nun champion',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 32,
              fontWeight: FontWeight.w800,
              height: 1.1,
              color: Colors.white,
            ),
          ),
        ),
        const SizedBox(height: 14),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.white.fade(0.08),
            borderRadius: BorderRadius.circular(30),
            border: Border.all(color: Colors.white.fade(0.15)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.star_rounded, color: kGold, size: 18),
              const SizedBox(width: 6),
              Text('Meilleur score : ${Stats.best}',
                  style: const TextStyle(fontWeight: FontWeight.w600)),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: kGold.fade(0.12),
            borderRadius: BorderRadius.circular(30),
            border: Border.all(color: kGold.fade(0.4)),
          ),
          child: Text('💰 ${fcfa(Stats.money)} • ${rankName(Stats.money)}',
              style: const TextStyle(
                  color: kGold, fontWeight: FontWeight.w700)),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final all = categories.expand((c) => c.questions).toList();
    return AppBackground(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 28, 20, 32),
        children: [
          FadeSlide(order: 0, child: _header()),
          const SizedBox(height: 28),
          FadeSlide(
            order: 1,
            child: CategoryCard(
              name: 'Mix de tous les thèmes',
              subtitle: '${all.length} questions • le défi ultime',
              icon: Icons.shuffle_rounded,
              color: const Color(0xFFA78BFA),
              onTap: () => _start('Mix', const Color(0xFFA78BFA), all),
            ),
          ),
          FadeSlide(
            order: 2,
            child: CategoryCard(
              name: 'Mode survie',
              subtitle:
                  'Une erreur et c’est fini • record : ${Stats.bestSurvival}',
              icon: Icons.favorite_rounded,
              color: const Color(0xFFF43F5E),
              onTap: () => _start('Survie', const Color(0xFFF43F5E), all,
                  survival: true),
            ),
          ),
          for (var i = 0; i < categories.length; i++)
            FadeSlide(
              order: i + 3,
              child: CategoryCard(
                name: categories[i].name,
                subtitle: '${categories[i].questions.length} questions',
                icon: categories[i].icon,
                color: categories[i].color,
                onTap: () => _start(categories[i].name, categories[i].color,
                    categories[i].questions),
              ),
            ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _menuButton('Boutique', Icons.storefront_rounded,
                    () => const ShopPage()),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _menuButton('Succès', Icons.emoji_events_rounded,
                    () => const AchievementsPage()),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            '10 questions • 20 secondes par question\n'
            'Réponds vite pour gagner plus de points !',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.white.fade(0.5), height: 1.5),
          ),
        ],
      ),
    );
  }
}

// ============================================================
//  PARTIE
// ============================================================
class QuizPage extends StatefulWidget {
  final String title;
  final Color color;
  final List<Question> pool;
  final bool survival;
  const QuizPage(
      {super.key,
      required this.title,
      required this.color,
      required this.pool,
      this.survival = false});

  @override
  State<QuizPage> createState() => _QuizPageState();
}

class _QuizPageState extends State<QuizPage> {
  static const double maxTime = 20;

  late List<Round> rounds;
  late List<bool?> results;
  int index = 0;
  int score = 0;
  int correct = 0;
  int streak = 0;
  int money = 0;
  int maxStreak = 0;
  int gain = 0;
  double timeLeft = maxTime;
  int? selected;
  bool revealed = false;
  final Set<int> hidden = {};
  bool used5050 = false;
  bool usedTime = false;
  bool failed = false;
  Timer? timer;

  @override
  void initState() {
    super.initState();
    final pool = List<Question>.from(widget.pool)..shuffle();
    rounds = (widget.survival ? pool : pool.take(10).toList())
        .map(Round.from)
        .toList();
    results = List<bool?>.filled(rounds.length, null);
    _startTimer();
  }

  @override
  void dispose() {
    timer?.cancel();
    super.dispose();
  }

  void _startTimer() {
    timer?.cancel();
    timeLeft = maxTime;
    timer = Timer.periodic(const Duration(milliseconds: 100), (_) {
      if (revealed || !mounted) return;
      setState(() => timeLeft = max(0, timeLeft - 0.1));
      if (timeLeft <= 0) _answer(null);
    });
  }

  void _answer(int? choice) {
    if (revealed) return;
    timer?.cancel();
    final ok = choice != null && choice == rounds[index].answer;
    ok ? HapticFeedback.lightImpact() : HapticFeedback.mediumImpact();
    setState(() {
      selected = choice;
      revealed = true;
      results[index] = ok;
      if (ok) {
        streak++;
        maxStreak = max(maxStreak, streak);
        correct++;
        final timeBonus = timeLeft.ceil() * 5;
        final streakBonus = min((streak - 1) * 25, 100);
        gain = 100 + timeBonus + streakBonus;
        score += gain;
        money += widget.survival
            ? 500
            : kLadder[min(index, kLadder.length - 1)];
      } else {
        streak = 0;
        gain = 0;
        if (widget.survival) failed = true;
      }
    });
  }

  void _next() {
    if (index + 1 >= rounds.length || failed) {
      final record = score > Stats.best;
      if (record) Stats.best = score;
      Stats.money += money;
      if (widget.survival && correct > Stats.bestSurvival) {
        Stats.bestSurvival = correct;
      }
      final ids = <String>{'first'};
      if (!widget.survival && correct == rounds.length) ids.add('perfect');
      if (maxStreak >= 5) ids.add('streak5');
      if (Stats.money >= 100000) ids.add('rich');
      if (widget.survival && correct >= 15) ids.add('survivor');
      final fresh = unlockAchievements(ids);
      Stats.save();
      FirebaseFirestore.instance.collection('scores').add({
        'pseudo': Stats.pseudo.isEmpty ? 'Anonyme' : Stats.pseudo,
        'score': score,
        'correct': correct,
        'argent': money,
        'mode': widget.survival ? 'survie' : 'classique',
        'theme': widget.title,
        'date': FieldValue.serverTimestamp(),
      }).catchError((_) {});
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => ResultPage(
            title: widget.title,
            color: widget.color,
            pool: widget.pool,
            score: score,
            correct: correct,
            money: money,
            totalMoney: Stats.money,
            total: widget.survival
                ? max(1, correct + (failed ? 1 : 0))
                : rounds.length,
            maxStreak: maxStreak,
            isRecord: record,
            survival: widget.survival,
            newBadges: fresh,
          ),
        ),
      );
      return;
    }
    setState(() {
      index++;
      selected = null;
      revealed = false;
      hidden.clear();
    });
    _startTimer();
  }

  void _use5050() {
    if (revealed || hidden.isNotEmpty) return;
    if (used5050) {
      if (Stats.stock5050 <= 0) return;
      Stats.stock5050--;
      Stats.save();
    }
    final r = rounds[index];
    final wrong = [
      for (var i = 0; i < r.options.length; i++)
        if (i != r.answer) i
    ]..shuffle();
    setState(() {
      used5050 = true;
      hidden.addAll(wrong.take(2));
    });
  }

  void _useTime() {
    if (revealed) return;
    if (usedTime) {
      if (Stats.stockTime <= 0) return;
      Stats.stockTime--;
      Stats.save();
    }
    setState(() {
      usedTime = true;
      timeLeft += 10;
    });
  }

  void _useSkip() {
    if (revealed || Stats.stockSkip <= 0) return;
    timer?.cancel();
    Stats.stockSkip--;
    Stats.save();
    _next();
  }

  // ---------- Widgets ----------
  Widget _timerCircle() {
    final urgent = timeLeft <= 5;
    final c = urgent ? Colors.redAccent : widget.color;
    final progress = (timeLeft / maxTime).clamp(0.0, 1.0);
    return SizedBox(
      width: 54,
      height: 54,
      child: Stack(
        alignment: Alignment.center,
        children: [
          SizedBox.expand(
            child: CircularProgressIndicator(
              value: progress,
              strokeWidth: 5,
              color: c,
              backgroundColor: Colors.white.fade(0.12),
            ),
          ),
          Text('${timeLeft.ceil()}',
              style:
                  TextStyle(fontWeight: FontWeight.w800, fontSize: 18, color: c)),
        ],
      ),
    );
  }

  Widget _scorePill() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: kGold.fade(0.15),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: kGold.fade(0.5)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.star_rounded, color: kGold, size: 18),
          const SizedBox(width: 4),
          Text('$score',
              style: const TextStyle(
                  color: kGold, fontWeight: FontWeight.w800, fontSize: 16)),
        ],
      ),
    );
  }

  Widget _segments() {
    return Row(
      children: [
        for (var i = 0; i < rounds.length; i++)
          Expanded(
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              height: 6,
              margin: const EdgeInsets.symmetric(horizontal: 2),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(3),
                color: results[i] == true
                    ? Colors.greenAccent
                    : results[i] == false
                        ? Colors.redAccent
                        : (i == index ? widget.color : Colors.white.fade(0.12)),
              ),
            ),
          ),
      ],
    );
  }

  Widget _questionCard(Round r) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 28),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [widget.color.fade(0.35), widget.color.fade(0.10)],
        ),
        border: Border.all(color: widget.color.fade(0.6)),
        boxShadow: [
          BoxShadow(
              color: widget.color.fade(0.25),
              blurRadius: 24,
              offset: const Offset(0, 10)),
        ],
      ),
      child: Text(
        r.text,
        textAlign: TextAlign.center,
        style: const TextStyle(
            fontSize: 21, fontWeight: FontWeight.w700, height: 1.3),
      ),
    );
  }

  Widget _option(int i, Round r) {
    final isHidden = hidden.contains(i);
    final isCorrect = revealed && i == r.answer;
    final isWrong = revealed && i == selected && i != r.answer;

    Color border = Colors.white.fade(0.18);
    List<Color> grad = [Colors.white.fade(0.09), Colors.white.fade(0.04)];
    Color badge = Colors.white.fade(0.12);
    if (isCorrect) {
      border = Colors.greenAccent;
      grad = [const Color(0xFF16A34A).fade(0.55), const Color(0xFF16A34A).fade(0.25)];
      badge = Colors.greenAccent.fade(0.9);
    } else if (isWrong) {
      border = Colors.redAccent;
      grad = [const Color(0xFFDC2626).fade(0.55), const Color(0xFFDC2626).fade(0.25)];
      badge = Colors.redAccent.fade(0.9);
    }

    return AnimatedOpacity(
      opacity: isHidden ? 0 : 1,
      duration: const Duration(milliseconds: 300),
      child: Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: GestureDetector(
          onTap: (revealed || isHidden) ? null : () => _answer(i),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 250),
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              gradient: LinearGradient(colors: grad),
              border: Border.all(color: border, width: 1.5),
            ),
            child: Row(
              children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 250),
                  width: 32,
                  height: 32,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(shape: BoxShape.circle, color: badge),
                  child: Text(
                    String.fromCharCode(65 + i),
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      color: (isCorrect || isWrong) ? Colors.black87 : Colors.white,
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Text(r.options[i],
                      style: const TextStyle(
                          fontSize: 16, fontWeight: FontWeight.w500)),
                ),
                if (isCorrect)
                  const Icon(Icons.check_circle_rounded, color: Colors.greenAccent),
                if (isWrong)
                  const Icon(Icons.cancel_rounded, color: Colors.redAccent),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _lifeline(String label, IconData icon, bool used, VoidCallback onTap) {
    final enabled = !used && !revealed;
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4),
        child: Opacity(
          opacity: enabled ? 1 : 0.35,
          child: Material(
            color: Colors.transparent,
            child: Ink(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                color: Colors.white.fade(0.08),
                border: Border.all(color: Colors.white.fade(0.2)),
              ),
              child: InkWell(
                borderRadius: BorderRadius.circular(16),
                onTap: enabled ? onTap : null,
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(icon, size: 18, color: kGold),
                      const SizedBox(width: 8),
                      Flexible(
                        child: Text(label,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style:
                                const TextStyle(fontWeight: FontWeight.w600)),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _bottom(Round r) {
    if (!revealed) {
      return Row(
        children: [
          _lifeline(
              Stats.stock5050 > 0 ? '50/50 ×${Stats.stock5050}' : '50/50',
              Icons.filter_2_rounded,
              used5050 && Stats.stock5050 <= 0,
              _use5050),
          _lifeline(
              Stats.stockTime > 0 ? '+10 s ×${Stats.stockTime}' : '+10 s',
              Icons.more_time_rounded,
              usedTime && Stats.stockTime <= 0,
              _useTime),
          if (Stats.stockSkip > 0)
            _lifeline('Passer ×${Stats.stockSkip}', Icons.skip_next_rounded,
                false, _useSkip),
        ],
      );
    }
    final ok = selected == r.answer;
    final c = ok ? Colors.greenAccent : Colors.redAccent;
    final text = selected == null
        ? '⏰ Temps écoulé ! Réponse : ${r.options[r.answer]}'
        : (ok
            ? '✅ Bonne réponse !  +$gain points'
            : '❌ Raté ! Réponse : ${r.options[r.answer]}');
    final fg = widget.color.computeLuminance() > 0.5
        ? Colors.black87
        : Colors.white;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: c.fade(0.15),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: c.fade(0.6)),
          ),
          child: Text(text,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
        ),
        const SizedBox(height: 10),
        FilledButton(
          onPressed: _next,
          style: FilledButton.styleFrom(
            backgroundColor: widget.color,
            foregroundColor: fg,
            minimumSize: const Size.fromHeight(54),
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            textStyle:
                const TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
          ),
          child: Text(index + 1 >= rounds.length || failed
              ? 'Voir mon résultat'
              : 'Question suivante'),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final r = rounds[index];

    return AppBackground(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
        child: Column(
          children: [
            Row(
              children: [
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close_rounded),
                ),
                Expanded(
                  child: Text(widget.title,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontSize: 17, fontWeight: FontWeight.w700)),
                ),
                _scorePill(),
                const SizedBox(width: 12),
                _timerCircle(),
              ],
            ),
            const SizedBox(height: 14),
            widget.survival ? const SizedBox(height: 6) : _segments(),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                    widget.survival
                        ? 'Question ${index + 1}'
                        : 'Question ${index + 1} / ${rounds.length}',
                    style: TextStyle(color: Colors.white.fade(0.6))),
                Text('💰 ${fcfa(money)}',
                    style: const TextStyle(
                        color: kGold, fontWeight: FontWeight.w800)),
                if (streak >= 2)
                  Text('🔥 Série x$streak',
                      style: const TextStyle(fontWeight: FontWeight.w700)),
              ],
            ),
            const SizedBox(height: 14),
            Expanded(
              child: SingleChildScrollView(
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 350),
                  transitionBuilder: (child, anim) => FadeTransition(
                    opacity: anim,
                    child: SlideTransition(
                      position: Tween<Offset>(
                              begin: const Offset(0.08, 0), end: Offset.zero)
                          .animate(anim),
                      child: child,
                    ),
                  ),
                  child: Column(
                    key: ValueKey(index),
                    children: [
                      _questionCard(r),
                      const SizedBox(height: 18),
                      for (var i = 0; i < r.options.length; i++) _option(i, r),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),
            _bottom(r),
          ],
        ),
      ),
    );
  }
}

// ============================================================
//  CONFETTIS
// ============================================================
class _Particle {
  final double x, speed, size, phase, rot;
  final Color color;
  _Particle(Random r)
      : x = r.nextDouble(),
        speed = 0.6 + r.nextDouble() * 0.8,
        size = 7 + r.nextDouble() * 7,
        phase = r.nextDouble() * 6.28,
        rot = r.nextDouble() * 6.28,
        color = const [
          kGold,
          Colors.pinkAccent,
          Colors.cyanAccent,
          Colors.greenAccent,
          Colors.purpleAccent,
          Colors.orangeAccent,
        ][r.nextInt(6)];
}

class Confetti extends StatefulWidget {
  const Confetti({super.key});

  @override
  State<Confetti> createState() => _ConfettiState();
}

class _ConfettiState extends State<Confetti>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
      vsync: this, duration: const Duration(seconds: 4))
    ..forward();
  late final List<_Particle> _parts = () {
    final r = Random();
    return List.generate(80, (_) => _Particle(r));
  }();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: AnimatedBuilder(
        animation: _c,
        builder: (_, _) => CustomPaint(
          size: Size.infinite,
          painter: _ConfettiPainter(_parts, _c.value),
        ),
      ),
    );
  }
}

class _ConfettiPainter extends CustomPainter {
  final List<_Particle> parts;
  final double t;
  _ConfettiPainter(this.parts, this.t);

  @override
  void paint(Canvas canvas, Size size) {
    final fade = 1 - max(0.0, (t - 0.8) / 0.2);
    for (final p in parts) {
      final y = -20 + (size.height + 40) * t * p.speed;
      if (y > size.height + 20) continue;
      final x = p.x * size.width + sin(t * 6 + p.phase) * 22;
      canvas.save();
      canvas.translate(x, y);
      canvas.rotate(p.rot + t * 8);
      canvas.drawRect(
        Rect.fromCenter(
            center: Offset.zero, width: p.size, height: p.size * 0.5),
        Paint()..color = p.color.fade(fade.clamp(0.0, 1.0).toDouble()),
      );
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(covariant _ConfettiPainter old) => old.t != t;
}

// ============================================================
//  RÉSULTAT
// ============================================================
class ResultPage extends StatelessWidget {
  final String title;
  final Color color;
  final List<Question> pool;
  final int score;
  final int correct;
  final int money;
  final int totalMoney;
  final int total;
  final int maxStreak;
  final bool isRecord;
  final bool survival;
  final List<Achievement> newBadges;

  const ResultPage({
    super.key,
    required this.title,
    required this.color,
    required this.pool,
    required this.score,
    required this.correct,
    required this.money,
    required this.totalMoney,
    required this.total,
    required this.maxStreak,
    required this.isRecord,
    this.survival = false,
    this.newBadges = const [],
  });

  Widget _chip(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white.fade(0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.fade(0.15)),
      ),
      child: Text(text, style: const TextStyle(fontWeight: FontWeight.w600)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final ratio = correct / total;
    final String rank;
    final String emoji;
    final int stars;
    if (ratio >= 0.9) {
      rank = 'Champion !';
      emoji = '🏆';
      stars = 3;
    } else if (ratio >= 0.7) {
      rank = 'Très bon joueur';
      emoji = '🥇';
      stars = 3;
    } else if (ratio >= 0.5) {
      rank = 'Bon joueur';
      emoji = '👍';
      stars = 2;
    } else if (ratio >= 0.3) {
      rank = 'Pas mal !';
      emoji = '💪';
      stars = 1;
    } else {
      rank = 'Apprenti';
      emoji = '📚';
      stars = 0;
    }

    return Stack(
      children: [
        AppBackground(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  FadeSlide(
                    order: 0,
                    child: Container(
                      width: 120,
                      height: 120,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.white.fade(0.06),
                        boxShadow: [
                          BoxShadow(
                              color: color.fade(0.45),
                              blurRadius: 40,
                              spreadRadius: 4),
                        ],
                      ),
                      child: Text(emoji, style: const TextStyle(fontSize: 60)),
                    ),
                  ),
                  const SizedBox(height: 20),
                  ShaderMask(
                    shaderCallback: (r) => LinearGradient(
                      colors: [Colors.white, color],
                    ).createShader(r),
                    child: Text(rank,
                        style: const TextStyle(
                            fontSize: 34,
                            fontWeight: FontWeight.w800,
                            color: Colors.white)),
                  ),
                  const SizedBox(height: 14),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      for (var i = 0; i < 3; i++)
                        TweenAnimationBuilder<double>(
                          tween: Tween(begin: 0, end: 1),
                          duration: Duration(milliseconds: 700 + i * 250),
                          curve: Curves.elasticOut,
                          builder: (_, v, _) => Transform.scale(
                            scale: v,
                            child: Icon(
                              Icons.star_rounded,
                              size: 52,
                              color: i < stars ? kGold : Colors.white.fade(0.18),
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  TweenAnimationBuilder<int>(
                    tween: IntTween(begin: 0, end: score),
                    duration: const Duration(milliseconds: 1300),
                    curve: Curves.easeOut,
                    builder: (_, v, _) => Text('$v',
                        style: const TextStyle(
                            fontSize: 60,
                            fontWeight: FontWeight.w900,
                            color: kGold)),
                  ),
                  Text('points', style: TextStyle(color: Colors.white.fade(0.6))),
                  if (isRecord)
                    Padding(
                      padding: const EdgeInsets.only(top: 10),
                      child: _chip('🎉 Nouveau record !'),
                    ),
                  const SizedBox(height: 18),
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    alignment: WrapAlignment.center,
                    children: [
                      _chip(survival
                          ? '✅ $correct bonnes réponses d’affilée'
                          : '✅ $correct / $total bonnes réponses'),
                      _chip('🔥 Série max : $maxStreak'),
                      _chip('💰 +${fcfa(money)}'),
                      _chip('🏦 Cagnotte : ${fcfa(totalMoney)}'),
                      for (final a in newBadges)
                        _chip('🏅 Succès : ${a.emoji} ${a.name}'),
                    ],
                  ),
                  const SizedBox(height: 30),
                  FilledButton.icon(
                    onPressed: () => Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(
                          builder: (_) =>
                              QuizPage(
                                  title: title,
                                  color: color,
                                  pool: pool,
                                  survival: survival)),
                    ),
                    icon: const Icon(Icons.replay_rounded),
                    label: const Text('Rejouer'),
                    style: FilledButton.styleFrom(
                      backgroundColor: color,
                      foregroundColor: color.computeLuminance() > 0.5
                          ? Colors.black87
                          : Colors.white,
                      minimumSize: const Size.fromHeight(54),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16)),
                      textStyle: const TextStyle(
                          fontSize: 17, fontWeight: FontWeight.w800),
                    ),
                  ),
                  const SizedBox(height: 10),
                  OutlinedButton.icon(
                    onPressed: () => shareWhatsApp(score, money),
                    icon: const Icon(Icons.share_rounded),
                    label: const Text('Partager sur WhatsApp'),
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size.fromHeight(54),
                      side: BorderSide(color: Colors.white.fade(0.3)),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16)),
                      textStyle: const TextStyle(
                          fontSize: 16, fontWeight: FontWeight.w600),
                    ),
                  ),
                  const SizedBox(height: 10),
                  OutlinedButton.icon(
                    onPressed: () =>
                        Navigator.popUntil(context, (route) => route.isFirst),
                    icon: const Icon(Icons.home_rounded),
                    label: const Text('Menu principal'),
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size.fromHeight(54),
                      side: BorderSide(color: Colors.white.fade(0.3)),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16)),
                      textStyle: const TextStyle(
                          fontSize: 16, fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        if (ratio >= 0.7) const Positioned.fill(child: Confetti()),
      ],
    );
  }
}

// ============================================================
//  BOUTIQUE
// ============================================================
class ShopPage extends StatefulWidget {
  const ShopPage({super.key});

  @override
  State<ShopPage> createState() => _ShopPageState();
}

class _ShopPageState extends State<ShopPage> {
  void _buy(int price, VoidCallback give) {
    if (Stats.money < price) return;
    setState(() {
      Stats.money -= price;
      give();
    });
    unlockAchievements({'shopper'});
    Stats.save();
  }

  Widget _item(String name, String desc, IconData icon, int price, int stock,
      VoidCallback give) {
    final can = Stats.money >= price;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white.fade(0.07),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.fade(0.15)),
      ),
      child: Row(
        children: [
          Icon(icon, color: kGold, size: 30),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name,
                    style: const TextStyle(
                        fontSize: 16, fontWeight: FontWeight.w700)),
                const SizedBox(height: 2),
                Text(desc,
                    style:
                        TextStyle(color: Colors.white.fade(0.6), fontSize: 13)),
                const SizedBox(height: 2),
                Text('En stock : $stock',
                    style: const TextStyle(color: kGold, fontSize: 13)),
              ],
            ),
          ),
          const SizedBox(width: 8),
          FilledButton(
            onPressed: can ? () => _buy(price, give) : null,
            child: Text(fcfa(price)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AppBackground(
      child: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
          children: [
            Row(
              children: [
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.arrow_back_rounded),
                ),
                const Text('Boutique',
                    style:
                        TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
              ],
            ),
            const SizedBox(height: 10),
            Center(
              child: Text('🏦 ${fcfa(Stats.money)}',
                  style: const TextStyle(
                      color: kGold, fontSize: 24, fontWeight: FontWeight.w900)),
            ),
            const SizedBox(height: 4),
            Center(
              child: Text(rankName(Stats.money),
                  style: TextStyle(color: Colors.white.fade(0.6))),
            ),
            const SizedBox(height: 20),
            _item('50/50', 'Retire 2 mauvaises réponses', Icons.filter_2_rounded,
                2000, Stats.stock5050, () => Stats.stock5050++),
            _item('+10 secondes', 'Ajoute du temps sur une question',
                Icons.more_time_rounded, 1500, Stats.stockTime,
                () => Stats.stockTime++),
            _item('Passer', 'Saute une question sans pénalité',
                Icons.skip_next_rounded, 3000, Stats.stockSkip,
                () => Stats.stockSkip++),
            const SizedBox(height: 8),
            Text(
              'Les jokers achetés s’ajoutent à ceux offerts à chaque partie.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white.fade(0.5)),
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================================
//  SUCCÈS
// ============================================================
class AchievementsPage extends StatelessWidget {
  const AchievementsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final done = Stats.badges.length;
    return AppBackground(
      child: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
          children: [
            Row(
              children: [
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.arrow_back_rounded),
                ),
                const Text('Succès',
                    style:
                        TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
              ],
            ),
            const SizedBox(height: 6),
            Center(
              child: Text('$done / ${kAchievements.length} débloqués',
                  style: TextStyle(color: Colors.white.fade(0.6))),
            ),
            const SizedBox(height: 16),
            for (final a in kAchievements)
              Opacity(
                opacity: Stats.badges.contains(a.id) ? 1 : 0.4,
                child: Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.white.fade(0.07),
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(
                      color: Stats.badges.contains(a.id)
                          ? kGold.fade(0.6)
                          : Colors.white.fade(0.15),
                    ),
                  ),
                  child: Row(
                    children: [
                      Text(Stats.badges.contains(a.id) ? a.emoji : '🔒',
                          style: const TextStyle(fontSize: 30)),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(a.name,
                                style: const TextStyle(
                                    fontSize: 16, fontWeight: FontWeight.w700)),
                            const SizedBox(height: 2),
                            Text(a.desc,
                                style: TextStyle(
                                    color: Colors.white.fade(0.6),
                                    fontSize: 13)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}