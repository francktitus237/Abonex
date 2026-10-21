import 'package:abonex/core/network/api_endpoints.dart';
import 'package:abonex/core/storage/settings_storage.dart';
import 'package:abonex/features/auth/data/models/user_model.dart';
import 'package:abonex/features/auth/domain/entities/user.dart';
import 'package:abonex/features/subscriptions/domain/entities/subscription.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test('les dépenses alimentaires restent compatibles avec la catégorie other', () {
    expect(SubscriptionCategory.parse('other'), SubscriptionCategory.other);
    expect(SubscriptionCategory.other.label, contains('alimentation'));
    expect(SubscriptionCategory.other.name, 'other');
  });

  group('ApiEndpoints', () {
    test('conserve le préfixe /api/v1/ de l’URL de base', () {
      final baseUrl = Uri.parse('http://10.0.2.2:8000/api/v1/');

      expect(
        baseUrl.resolve(ApiEndpoints.subscriptions).toString(),
        'http://10.0.2.2:8000/api/v1/subscriptions/',
      );
      expect(
        baseUrl.resolve(ApiEndpoints.subscription('42')).toString(),
        'http://10.0.2.2:8000/api/v1/subscriptions/42/',
      );
    });
  });

  group('SettingsStorage', () {
    test('n’affiche le guide de connexion qu’une seule fois', () async {
      SharedPreferences.setMockInitialValues({});
      final storage = SettingsStorage(await SharedPreferences.getInstance());

      expect(storage.firstLoginGuideSeen, isFalse);
      await storage.setFirstLoginGuideSeen();
      expect(storage.firstLoginGuideSeen, isTrue);
    });
  });

  group('UserModel', () {
    test('parse le JSON de l\'API (snake_case → camelCase)', () {
      final model = UserModel.fromJson({
        'id': '42',
        'email': 'patron@abonex.com',
        'first_name': 'Jean',
        'last_name': 'Dupont',
        'role': 'owner',
      });

      expect(model.firstName, 'Jean');
      expect(model.lastName, 'Dupont');
      expect(model.role, UserRole.owner);
      expect(model.toEntity().fullName, 'Jean Dupont');
    });

    test('un rôle inconnu retombe sur viewer (moindre privilège)', () {
      final model = UserModel.fromJson({
        'id': '1',
        'email': 'a@b.c',
        'role': 'super_admin_inconnu',
      });

      expect(model.role, UserRole.viewer);
      expect(model.role.canManageUsers, isFalse);
    });
  });
}
