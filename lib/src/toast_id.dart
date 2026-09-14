/// Identifies one toast.
///
/// `show` returns one. A caller can also make its own, such as
/// `ToastId('connection')`; ids are equal when their values are.
extension type const ToastId(Object value) {}

/// The value of an id `show` generated. Compared by identity, so no id a
/// caller makes can equal it.
final class AutoToastIdValue {
  AutoToastIdValue(this.serial);

  final int serial;

  @override
  String toString() => '#$serial';
}
