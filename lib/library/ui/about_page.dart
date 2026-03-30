import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../auth/logic/auth_provider.dart';
import '../../core/widgets/app_bottom_nav_bar.dart';
import '../../core/constants/app_colors.dart';
import '../../core/config/social_config.dart';

class AboutPage extends StatefulWidget {
  const AboutPage({super.key});

  @override
  State<AboutPage> createState() => _AboutPageState();
}

class _AboutPageState extends State<AboutPage> {
  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: Text(
          'About App',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: isDark
                ? AppColors.textPrimaryDark
                : AppColors.textPrimaryLight,
            letterSpacing: 1.1,
          ),
        ),
        backgroundColor: isDark
            ? AppColors.scoutEliteNavy
            : AppColors.backgroundLight,
        elevation: 0,
        centerTitle: true,
        iconTheme: IconThemeData(
          color: isDark
              ? AppColors.textPrimaryDark
              : AppColors.textPrimaryLight,
        ),
      ),
      body: Stack(
        children: [
          Container(
            decoration: BoxDecoration(
              color: isDark
                  ? AppColors.scoutEliteNavy
                  : AppColors.backgroundLight,
            ),
          ),
          Positioned(
            top: -100,
            right: -100,
            child: Container(
              width: 300,
              height: 300,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.goldAccent.withValues(alpha: 0.1),
              ),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 80, sigmaY: 80),
                child: Container(color: Colors.transparent),
              ),
            ),
          ),
          Positioned(
            bottom: 100,
            left: -50,
            child: Container(
              width: 200,
              height: 200,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.primaryBlue.withValues(alpha: 0.05),
              ),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 60, sigmaY: 60),
                child: Container(color: Colors.transparent),
              ),
            ),
          ),
          AboutContent(isDark: isDark),
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: AppBottomNavBar(
              currentPage: 'about',
              isAuthenticated: authProvider.isAuthenticated,
            ),
          ),
        ],
      ),
    );
  }
}

class AboutContent extends StatelessWidget {
  final bool isDark;

  const AboutContent({super.key, required this.isDark});

  Future<void> _launchUrl(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return SingleChildScrollView(
      physics: const ClampingScrollPhysics(),
      padding: EdgeInsets.only(
        top: MediaQuery.of(context).padding.top + 80,
        bottom: 140,
        left: 20,
        right: 20,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          _AnimatedEntrance(
            delay: 100,
            child: Column(
              children: [
                const Text(
                  'OUR HERITAGE',
                  style: TextStyle(
                    color: AppColors.goldAccent,
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 4,
                  ),
                ),
                const SizedBox(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    _buildLogoCircle(
                      'assets/images/church_logo.png',
                      90,
                      label: 'Church',
                      isDark: isDark,
                      paddingFactor: 0.2,
                    ),
                    const SizedBox(width: 20),
                    _buildLogoCircle(
                      'assets/images/mas_logo.png',
                      130,
                      isMain: true,
                      isDark: isDark,
                      label: 'MAS',
                      paddingFactor: 0.06,
                    ),
                    const SizedBox(width: 20),
                    _buildLogoCircle(
                      'assets/images/Digital_Logo.PNG',
                      90,
                      isDark: isDark,
                      label: 'Digital Team',
                      paddingFactor: 0.0005,
                      backgroundColor: const Color(0xFF275EF9),
                    ),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(height: 48),

          _AnimatedEntrance(
            delay: 300,
            child: Column(
              children: [
                ShaderMask(
                  shaderCallback: (bounds) => LinearGradient(
                    colors: isDark
                        ? [Colors.white, AppColors.goldAccent]
                        : [AppColors.scoutEliteNavy, AppColors.goldAccent],
                  ).createShader(bounds),
                  child: Text(
                    'Scout Digital Library',
                    style: theme.textTheme.displaySmall?.copyWith(
                      color: isDark ? Colors.white : AppColors.scoutEliteNavy,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1.5,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.goldAccent.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(30),
                    border: Border.all(
                      color: AppColors.goldAccent.withValues(alpha: 0.2),
                      width: 1,
                    ),
                  ),
                  child: const Text(
                    'Digital Excellence in Scouting',
                    style: TextStyle(
                      color: AppColors.goldAccent,
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 48),

          _AnimatedEntrance(
            delay: 500,
            child: _buildGlassCard(
              title: 'Our Mission',
              icon: Icons.explore_rounded,
              content:
                  'Transforming the Scouting experience through digital innovation. Michael Archangel Scout Sheraton is committed to merging traditional values with modern technology to empower the next generation of leaders.',
              isDark: isDark,
            ),
          ),

          const SizedBox(height: 20),

          _AnimatedEntrance(
            delay: 600,
            child: _buildGlassCard(
              title: 'Knowledge Hub',
              icon: Icons.auto_stories_rounded,
              content:
                  'The Digital Library serves as a central hub for all scouting resources, providing instant access to thousands of media assets, guides, and educational materials for scouts and leaders worldwide.',
              isDark: isDark,
            ),
          ),

          const SizedBox(height: 20),

          _AnimatedEntrance(
            delay: 700,
            child: _buildGlassCard(
              title: 'Scout Digital Team',
              icon: Icons.terminal_rounded,
              content:
                  'Developed with passion by the Scout Digital Team. We are dedicated to building robust, secure, and user-centric solutions that support the spiritual and technical growth of our youth.',
              isDark: isDark,
            ),
          ),

          const SizedBox(height: 40),

          _AnimatedEntrance(
            delay: 800,
            child: Column(
              children: [
                Text(
                  'CONNECT WITH US',
                  style: TextStyle(
                    color: isDark
                        ? AppColors.textSecondaryDark
                        : AppColors.textSecondaryLight,
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 2,
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _buildSocialButton(
                      Icons.language,
                      () => _launchUrl(SocialConfig.websiteUrl),
                      label: 'Web',
                      isDark: isDark,
                    ),
                    const SizedBox(width: 15),
                    _buildSocialButton(
                      Icons.facebook,
                      () => _launchUrl(SocialConfig.facebookUrl),
                      label: 'FB',
                      isDark: isDark,
                    ),
                    const SizedBox(width: 15),
                    _buildSocialButton(
                      Icons.camera_alt_outlined,
                      () => _launchUrl(SocialConfig.instagramUrl),
                      label: 'IG',
                      isDark: isDark,
                    ),
                    const SizedBox(width: 15),
                    _buildSocialButton(
                      Icons.music_note_outlined,
                      () => _launchUrl(SocialConfig.anghamiUrl),
                      label: 'Anghami',
                      isDark: isDark,
                    ),
                    const SizedBox(width: 15),
                    _buildSocialButton(
                      Icons.email_outlined,
                      () => _launchUrl('mailto:${SocialConfig.contactEmail}'),
                      label: 'Mail',
                      isDark: isDark,
                    ),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(height: 48),

          _AnimatedEntrance(
            delay: 900,
            child: Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: isDark
                    ? AppColors.cardDarkElevated
                    : AppColors.cardLight,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(
                  color: isDark
                      ? Colors.white.withValues(alpha: 0.05)
                      : AppColors.divider,
                  width: 1,
                ),
              ),
              child: Column(
                children: [
                  _buildStatRow(
                    'Build Ver',
                    '1.0.0+4',
                    icon: Icons.info_outline,
                    isDark: isDark,
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 60),

          _AnimatedEntrance(
            delay: 1000,
            child: Column(
              children: [
                Text(
                  '© 2026 MICHAEL ARCHANGEL SCOUT SHERATON',
                  style: TextStyle(
                    color: isDark
                        ? AppColors.textTertiaryDark
                        : AppColors.textTertiaryLight,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.5,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Crafted with pride by the MAS Digital Team.',
                  style: TextStyle(
                    color: isDark
                        ? AppColors.textTertiaryDark
                        : AppColors.textTertiaryLight,
                    fontSize: 10,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
          const SizedBox(height: 40),
        ],
      ),
    );
  }

  Widget _buildLogoCircle(
    String path,
    double size, {
    bool isMain = false,
    required String label,
    required bool isDark,
    Color? backgroundColor,
    double paddingFactor = 0.08,
  }) {
    return Column(
      children: [
        Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            color: backgroundColor ?? Colors.white,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color:
                    (isMain
                            ? AppColors.goldAccent
                            : (isDark ? Colors.black : Colors.grey))
                        .withValues(alpha: 0.3),
                blurRadius: 15,
                spreadRadius: isMain ? 4 : 2,
              ),
            ],
            border: Border.all(
              color: isMain
                  ? AppColors.goldAccent
                  : (isDark
                        ? Colors.white.withValues(alpha: 0.2)
                        : Colors.grey.shade300),
              width: isMain ? 3 : 1,
            ),
          ),
          padding: EdgeInsets.all(size * paddingFactor),
          clipBehavior: Clip.antiAlias,
          child: Image.asset(
            path,
            fit: BoxFit.cover,
            errorBuilder: (context, error, stackTrace) => Icon(
              Icons.broken_image_outlined,
              size: size * 0.4,
              color: AppColors.scoutEliteNavy,
            ),
          ),
        ),
        const SizedBox(height: 12),
        Text(
          label,
          style: TextStyle(
            color: isMain
                ? AppColors.goldAccent
                : (isDark
                      ? AppColors.textTertiaryDark
                      : AppColors.textSecondaryLight),
            fontSize: 14,
            fontWeight: isMain ? FontWeight.w900 : FontWeight.w700,
            letterSpacing: 1.2,
          ),
        ),
      ],
    );
  }

  Widget _buildGlassCard({
    required String title,
    required IconData icon,
    required String content,
    required bool isDark,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: isDark
            ? AppColors.cardDarkElevated.withValues(alpha: 0.5)
            : AppColors.cardLight,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: isDark
              ? Colors.white.withValues(alpha: 0.08)
              : AppColors.divider,
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.goldAccent.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(icon, color: AppColors.goldAccent, size: 22),
              ),
              const SizedBox(width: 16),
              Text(
                title,
                style: TextStyle(
                  color: isDark
                      ? AppColors.textPrimaryDark
                      : AppColors.textPrimaryLight,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            content,
            style: TextStyle(
              color: isDark
                  ? AppColors.textSecondaryDark
                  : AppColors.textSecondaryLight,
              height: 1.6,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatRow(
    String label,
    String value, {
    required IconData icon,
    required bool isDark,
  }) {
    return Row(
      children: [
        Icon(
          icon,
          size: 16,
          color: AppColors.goldAccent.withValues(alpha: 0.5),
        ),
        const SizedBox(width: 12),
        Text(
          label,
          style: TextStyle(
            color: isDark
                ? AppColors.textSecondaryDark
                : AppColors.textSecondaryLight,
            fontSize: 13,
            fontWeight: FontWeight.w500,
          ),
        ),
        const Spacer(),
        Text(
          value,
          style: TextStyle(
            color: isDark
                ? AppColors.textPrimaryDark
                : AppColors.textPrimaryLight,
            fontSize: 13,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  Widget _buildSocialButton(
    IconData icon,
    VoidCallback onTap, {
    required String label,
    required bool isDark,
  }) {
    return Column(
      children: [
        Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(12),
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isDark
                    ? Colors.white.withValues(alpha: 0.05)
                    : AppColors.scoutEliteNavy.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isDark ? Colors.white10 : AppColors.divider,
                ),
              ),
              child: Icon(
                icon,
                color: isDark
                    ? AppColors.textPrimaryDark
                    : AppColors.textPrimaryLight,
                size: 20,
              ),
            ),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          label,
          style: TextStyle(
            color: isDark
                ? AppColors.textTertiaryDark
                : AppColors.textTertiaryLight,
            fontSize: 8,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }
}

class _AnimatedEntrance extends StatelessWidget {
  final Widget child;
  final int delay;

  const _AnimatedEntrance({required this.child, required this.delay});

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: 1.0),
      duration: const Duration(milliseconds: 800),
      curve: Curves.easeOutCubic,
      builder: (context, value, child) {
        return Opacity(
          opacity: value,
          child: Transform.translate(
            offset: Offset(0, 30 * (1 - value)),
            child: child,
          ),
        );
      },
      child: Padding(
        padding: EdgeInsets.only(top: delay / 100),
        child: child,
      ),
    );
  }
}
