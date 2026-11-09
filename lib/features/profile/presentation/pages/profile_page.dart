import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:food_delivery/core/di/injection.dart';
import 'package:food_delivery/core/extensions/context_extensions.dart';
import 'package:food_delivery/core/router/routes.dart';
import 'package:food_delivery/core/theme/app_theme.dart';
import 'package:food_delivery/core/utils/phone_formatter.dart';
import 'package:food_delivery/core/widgets/common_widgets.dart';
import 'package:food_delivery/features/address/presentation/bloc/address_cubits.dart';
import 'package:food_delivery/features/auth/domain/entities/app_user.dart';
import 'package:food_delivery/features/auth/presentation/bloc/session_cubit.dart';
import 'package:food_delivery/features/cart/presentation/bloc/cart_cubit.dart';
import 'package:food_delivery/features/profile/domain/repositories/profile_repository.dart';
import 'package:food_delivery/features/profile/presentation/bloc/profile_cubits.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

class ProfilePage extends StatelessWidget {
  const ProfilePage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(create: (_) => getIt<ProfileCubit>(), child: const ProfileView());
  }
}

class ProfileView extends StatelessWidget {
  const ProfileView({super.key});

  Future<void> _pickAvatar(BuildContext context) async {
    final l10n = context.l10n;
    final source = await showModalBottomSheet<AvatarSource>(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: Text(l10n.fromGallery),
              onTap: () => Navigator.pop(context, AvatarSource.gallery),
            ),
            ListTile(
              leading: const Icon(Icons.photo_camera_outlined),
              title: Text(l10n.fromCamera),
              onTap: () => Navigator.pop(context, AvatarSource.camera),
            ),
          ],
        ),
      ),
    );
    if (source != null && context.mounted) {
      await context.read<ProfileCubit>().changeAvatar(source);
    }
  }

  Future<void> _logout(BuildContext context) async {
    final ok = await showConfirmDialog(
      context,
      title: context.l10n.logoutQuestion,
      confirmLabel: context.l10n.logout,
    );
    if (ok && context.mounted) await context.read<ProfileCubit>().logout();
  }

  Future<void> _delete(BuildContext context) async {
    final ok = await showConfirmDialog(
      context,
      title: context.l10n.deleteAccount,
      body: context.l10n.deleteAccountQuestion,
      confirmLabel: context.l10n.delete,
      destructive: true,
    );
    if (ok && context.mounted) await context.read<ProfileCubit>().deleteAccount();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final user = context.select<SessionCubit, AppUser?>((c) => c.user);
    return BlocListener<ProfileCubit, ProfileState>(
      listener: (context, state) {
        if (state is ProfileFailure) context.showSnack(state.failure.message(l10n));
        if (state is ProfileSuccess && context.read<SessionCubit>().user == null) {
          // Logged out: local data is wiped — refresh global cubits.
          context.read<CartCubit>().load();
          context.read<CurrentAddressCubit>().reset();
        }
      },
      child: Scaffold(
        appBar: AppBar(title: Text(l10n.profileTitle)),
        body: ListView(
          children: [
            const SizedBox(height: AppSpacing.lg),
            Center(
              child: BlocBuilder<ProfileCubit, ProfileState>(
                builder: (context, state) => _Avatar(
                  url: user?.avatarUrl,
                  loading: state is ProfileLoading,
                  onTap: () => _pickAvatar(context),
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            Center(child: Text(user?.name ?? '', style: context.text.titleLarge)),
            Center(
              child: Text(
                user == null ? '' : PhoneUtils.formatE164(user.phone),
                style: context.text.bodyMedium,
              ),
            ),
            const SizedBox(height: AppSpacing.xl),
            ListTile(
              leading: const Icon(Icons.receipt_long_rounded),
              title: Text(l10n.myOrders),
              trailing: const Icon(Icons.chevron_right_rounded),
              onTap: () => context.push(Routes.orders),
            ),
            ListTile(
              leading: const Icon(Icons.location_on_outlined),
              title: Text(l10n.savedAddresses),
              trailing: const Icon(Icons.chevron_right_rounded),
              onTap: () => context.push(Routes.addresses),
            ),
            ListTile(
              leading: const Icon(Icons.settings_outlined),
              title: Text(l10n.settingsTitle),
              trailing: const Icon(Icons.chevron_right_rounded),
              onTap: () => context.push(Routes.settings),
            ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.logout_rounded),
              title: Text(l10n.logout),
              onTap: () => _logout(context),
            ),
            ListTile(
              leading: Icon(Icons.delete_forever_outlined, color: context.colors.error),
              title: Text(l10n.deleteAccount, style: TextStyle(color: context.colors.error)),
              onTap: () => _delete(context),
            ),
          ],
        ),
      ),
    );
  }
}

class _Avatar extends StatelessWidget {
  const _Avatar({required this.url, required this.loading, required this.onTap});

  final String? url;
  final bool loading;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: context.l10n.changeAvatar,
      child: GestureDetector(
        onTap: loading ? null : onTap,
        child: Stack(
          alignment: Alignment.center,
          children: [
            CircleAvatar(
              radius: 48,
              backgroundColor: context.colors.primaryContainer,
              backgroundImage: url == null ? null : CachedNetworkImageProvider(url!, maxWidth: 300),
              child: url == null
                  ? Icon(Icons.person_rounded, size: 48, color: context.colors.primary)
                  : null,
            ),
            if (loading) const CircularProgressIndicator(),
            Positioned(
              right: 0,
              bottom: 0,
              child: CircleAvatar(
                radius: 16,
                backgroundColor: context.colors.primary,
                child: Icon(Icons.camera_alt_rounded, size: 16, color: context.colors.onPrimary),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
