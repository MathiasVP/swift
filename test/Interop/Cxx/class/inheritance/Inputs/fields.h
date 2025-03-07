template <class From, class To>
To __swift_interopStaticCast(From from) { return from; }

struct HasThreeFields {
  int a = 1;
  int b = 2;
  int c = 3;
};

struct DerivedWithOneField : HasThreeFields {
  int d = 4;
};

struct HasOneField {
  int e = 5;
};

struct DerivedFromAll : HasOneField, DerivedWithOneField {
  int f = 6;
};

// Non trivial types:

struct NonTrivial {
  NonTrivial() {}
  ~NonTrivial() {}
};

struct NonTrivialHasThreeFields : NonTrivial {
  int a = 1;
  int b = 2;
  int c = 3;
};

struct NonTrivialDerivedWithOneField : NonTrivialHasThreeFields {
  int d = 4;
};

struct NonTrivialHasOneField {
  NonTrivialHasOneField() {}
  ~NonTrivialHasOneField() {}

  int e = 5;
};

struct NonTrivialDerivedFromAll : NonTrivialHasOneField, NonTrivialDerivedWithOneField {
  int f = 6;
};
