abstract final class Routes {
  static const welcome = '/welcome';
  static const welcomeCurrency = '/welcome/currency';
  static const lock = '/lock';
  static const dashboard = '/dashboard';
  static const transactions = '/transactions';
  static const transactionNew = '/transactions/new';
  static String transactionEdit(String id) => '/transactions/$id';
  static const budgets = '/budgets';
  static const budgetEdit = '/budgets/edit';
  static const settings = '/settings';
  static const categories = '/settings/categories';
  static const categoryNew = '/settings/categories/new';
  static String categoryEdit(String id) => '/settings/categories/$id';
  static const export = '/settings/export';
  static const backup = '/settings/backup';
  static const backupSignIn = '/settings/backup/sign-in';
  static const backupVerify = '/settings/backup/verify';
  static const about = '/settings/about';
}
