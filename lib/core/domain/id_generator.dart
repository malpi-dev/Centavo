/// Generates unique ids for new entities.
// ignore: one_member_abstracts, injectable seam so tests can use fixed ids
abstract interface class IdGenerator {
  String newId();
}
