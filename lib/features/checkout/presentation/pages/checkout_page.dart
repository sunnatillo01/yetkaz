import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:food_delivery/core/di/injection.dart';
import 'package:food_delivery/core/extensions/context_extensions.dart';
import 'package:food_delivery/core/router/routes.dart';
import 'package:food_delivery/core/theme/app_theme.dart';
import 'package:food_delivery/core/widgets/common_widgets.dart';
import 'package:food_delivery/features/address/domain/entities/address.dart';
import 'package:food_delivery/features/address/presentation/bloc/address_cubits.dart';
import 'package:food_delivery/features/address/presentation/widgets/address_label_text.dart';
import 'package:food_delivery/features/cart/presentation/bloc/cart_cubit.dart';
import 'package:food_delivery/features/checkout/presentation/bloc/checkout_bloc.dart';
import 'package:food_delivery/features/order_tracking/domain/entities/order.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

class CheckoutPage extends StatelessWidget {
  const CheckoutPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(create: (_) => getIt<CheckoutBloc>(), child: const CheckoutView());
  }
}

class CheckoutView extends StatelessWidget {
  const CheckoutView({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final bloc = context.read<CheckoutBloc>();
    return BlocConsumer<CheckoutBloc, CheckoutState>(
      listenWhen: (a, b) => a.status != b.status || a.addressMissing != b.addressMissing,
      listener: (context, state) {
        if (state.addressMissing) context.showSnack(l10n.addressRequired);
        switch (state.status) {
          case CheckoutSuccess(:final orderId):
            context.read<CartCubit>().load(); // cart was cleared in storage
            context.go(Routes.order(orderId));
          case CheckoutFailure(:final failure):
            context.showSnack(failure.message(l10n));
          default:
        }
      },
      builder: (context, state) {
        final cartState = context.watch<CartCubit>().state;
        final totals = cartState is CartSuccess ? cartState.totals : null;
        return Scaffold(
          appBar: AppBar(title: Text(l10n.checkoutTitle)),
          body: ListView(
            padding: const EdgeInsets.only(bottom: AppSpacing.xl),
            children: [
              SectionTitle(l10n.deliveryAddress),
              const _AddressTile(),
              SectionTitle(l10n.paymentMethod),
              RadioGroup<PaymentMethod>(
                groupValue: state.paymentMethod,
                onChanged: (m) => bloc.add(CheckoutEvent.paymentMethodChanged(m!)),
                child: Column(
                  children: [
                    RadioListTile(
                      value: PaymentMethod.cash,
                      title: Text(l10n.paymentCash),
                      secondary: const Icon(Icons.payments_outlined),
                    ),
                    RadioListTile(
                      value: PaymentMethod.card,
                      title: Text(l10n.paymentCard),
                      subtitle: Text(l10n.cardSimulationNote),
                      secondary: const Icon(Icons.credit_card_rounded),
                    ),
                  ],
                ),
              ),
              SectionTitle(l10n.courierNote),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
                child: TextField(
                  maxLines: 3,
                  minLines: 2,
                  maxLength: 300,
                  decoration: InputDecoration(hintText: l10n.courierNoteHint),
                  onChanged: (v) => bloc.add(CheckoutEvent.noteChanged(v)),
                ),
              ),
              if (totals != null)
                Padding(
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  child: Column(
                    children: [
                      _line(context, l10n.subtotal, totals.subtotal),
                      _line(context, l10n.deliveryFee, totals.deliveryFee),
                      _line(context, l10n.serviceFee, totals.serviceFee),
                      const Divider(),
                      _line(context, l10n.total, totals.total, bold: true),
                    ],
                  ),
                ),
            ],
          ),
          bottomNavigationBar: SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: LoadingButton(
                key: const Key('place_order'),
                label: l10n.placeOrder,
                isLoading: state.status is CheckoutLoading,
                onPressed: () => bloc.add(
                  CheckoutEvent.submitted(
                    cart: cartState.cart,
                    address: context.read<CurrentAddressCubit>().state,
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _line(BuildContext context, String label, int amount, {bool bold = false}) {
    final style = bold ? context.text.titleMedium : context.text.bodyMedium;
    return Row(
      children: [
        Expanded(child: Text(label, style: style)),
        Text(context.money(amount), style: style),
      ],
    );
  }
}

class _AddressTile extends StatelessWidget {
  const _AddressTile();

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return BlocBuilder<CurrentAddressCubit, Address?>(
      builder: (context, address) => ListTile(
        leading: Icon(address?.label.icon ?? Icons.add_location_alt_outlined),
        title: Text(address?.text ?? l10n.chooseAddress),
        subtitle: address == null || address.details.isEmpty
            ? null
            : Text(address.details.join(', ')),
        trailing: const Icon(Icons.chevron_right_rounded),
        onTap: () =>
            context.push(address == null ? Routes.addressPick : '${Routes.addresses}?select=1'),
      ),
    );
  }
}
