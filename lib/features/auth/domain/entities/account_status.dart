enum AccountStatus {
  active('Active', 'Account is fully active and verified'),
  pending('Under Review', 'Application is currently under administrative review'),
  suspended('Suspended', 'Account access is temporarily suspended'),
  disabled('Disabled', 'Account has been deactivated');

  final String label;
  final String description;

  const AccountStatus(this.label, this.description);

  static AccountStatus fromString(String? value) {
    if (value == null) return AccountStatus.active;
    return AccountStatus.values.firstWhere(
      (status) => status.name.toLowerCase() == value.toLowerCase(),
      orElse: () => AccountStatus.active,
    );
  }
}
