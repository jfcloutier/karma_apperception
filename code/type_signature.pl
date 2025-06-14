:- module(type_signature, [
    min_type_signature/2, 
    extended_type_signature/3,
    all_predicate_names/2,
    all_binary_predicate_names/2, 
    binary_predicate_name/2,
    applicable_predicate_name/3,
    predicates_observed_to_vary/3
    ]).
/*
[load, load_tests].
[utils(logger), tests(apperception/leds_observations), tests(apperception/eca_observations), apperception(domains), apperception(sequence), apperception(type_signature)].
sequence(eca_observations, Sequence), min_type_signature(Sequence, MinTypeSignature), predicates_observed_to_vary(MinTypeSignature, Sequence, PredicateNames).
*/

:- use_module(utils(logger)).
:- use_module(apperception(domains)).

% The minimum type signature manifested by a sequence of obaservations.
min_type_signature(Sequence, TypeSignature) :-
    observed_object_types(Sequence, ObjectTypes),
    observed_objects(Sequence, Objects),
    observed_predicate_types(Sequence, PredicateTypes),
    TypeSignature = type_signature{object_types:ObjectTypes, objects:Objects, predicate_types:PredicateTypes}.

% An extended type signature given a starting type signature, extension bounds, and a region with limits on the extensions that can be produced.
extended_type_signature(TypeSignature,
                        region(NumObjectTypes, NumObjects, NumPredicateTypes),
                        ExtendedTypeSignature) :-
    extended_object_types(TypeSignature.object_types, NumObjectTypes, ExtendedObjectTypes),
    extended_objects(TypeSignature.objects, ExtendedObjectTypes, NumObjects, ExtendedObjects),
    extended_predicate_types(TypeSignature.predicate_types, ExtendedObjectTypes, NumPredicateTypes, ExtendedPredicateTypes),
    typed_variables(ExtendedObjects, ExtendedObjectTypes, TypedVariables),
    sort(ExtendedObjectTypes, ObjectTypes),
    sort(ExtendedPredicateTypes, PredicateTypes),
    sort(ExtendedObjects, Objects),
    ExtendedTypeSignature = type_signature{object_types:ObjectTypes, objects:Objects, predicate_types:PredicateTypes, typed_variables:TypedVariables}.

% The names of all predicates observed to vary
predicates_observed_to_vary(TypeSignature, Sequence, PredicateNames) :-
    all_predicate_names(TypeSignature, AllPredicateNames),
    setof(PredicateName, (member(PredicateName, AllPredicateNames), observed_to_vary(PredicateName, Sequence)), PredicateNames).

observed_to_vary(PredicateName, Sequence) :-
    select(State1, Sequence, RestOfSequence),
    member(Observation1, State1),
    Observation1 =.. [_, PredicateName, [Object1, Value1], _],
    member(State2, RestOfSequence),
    member(Observation2, State2),
    Observation2 =.. [_, PredicateName, [Object1, Value2], _],
    Value1 \== Value2,
    !.

all_predicate_names(TypeSignature, AllPredicateNames) :-
    PredicateTypes = TypeSignature.predicate_types,
    findall(PredicateName, predicate_name(PredicateTypes, PredicateName), AllPredicateNames).

% All relations in a type signature
all_binary_predicate_names(TypeSignature, AllBinaryPredicateNames) :-
    PredicateTypes = TypeSignature.predicate_types,
    findall(BinaryPredicateName, binary_predicate_name(PredicateTypes, BinaryPredicateName), AllBinaryPredicateNames).

% The name of a predicate in a list of predicate types.
predicate_name(PredicateTypes, PredicateName) :-
    member(predicate(PredicateName, _), PredicateTypes).

% The name of a predicate which can be applied to a type of object.
applicable_predicate_name(TypeSignature, ObjectType, PredicateName) :-
    member(predicate(PredicateName, ArgTypes), TypeSignature.predicate_types),
    member(object_type(ObjectType), ArgTypes).

% The name of a binary predicate in a list of predicate types.
binary_predicate_name(PredicateTypes, BinaryPredicateName) :-
    member(predicate(BinaryPredicateName, [object_type(_), object_type(_)]), PredicateTypes).

% The set of observed object types
observed_object_types(Sequence, ObjectTypes) :-
    flatten(Sequence, AllObservations),
    observed_object_types(AllObservations, [], ObjectTypes).

% The set of observed objects
observed_objects(Sequence, Objects) :-
    flatten(Sequence, AllObservations),
    observed_objects(AllObservations, [], Objects).

% The set of observed predicate types
observed_predicate_types(Sequence, PredicateTypes) :-
    flatten(Sequence, AllObservations),
    observed_predicate_types(AllObservations, [], PredicateTypes).

% sensed(on, [object(cell, c1), false], 1) =..  [sensed, on, [object(cell, c1), false], 1].
observed_object_types([], ObjectTypes, ObjectTypes).
observed_object_types([Observation | Others], Acc, ObjectTypes) :-
    Observation =.. [_, _, [object(ObjectType, _), _], _],
    (memberchk(object_type(ObjectType), Acc) -> 
        observed_object_types(Others, Acc, ObjectTypes)
        ;
        observed_object_types(Others, [object_type(ObjectType) | Acc], ObjectTypes)
    ).

observed_objects([], Objects, Objects).
observed_objects([Observation | Others], Acc, Objects) :-
    Observation =.. [_, _, [Object, _], _],
    (memberchk(Object, Acc) -> 
        observed_objects(Others, Acc, Objects)
        ;
        observed_objects(Others, [Object | Acc], Objects)
    ).

observed_predicate_types([], PredicateTypes, PredicateTypes).
observed_predicate_types([Observation | Others], Acc, PredicateTypes) :-
     Observation =.. [_, Predicate, Args, _],
     implied_predicate_type(Predicate, Args, PredicateType),
     (memberchk(PredicateType, Acc) ->
        observed_predicate_types(Others, Acc, PredicateTypes)
        ;
        observed_predicate_types(Others, [PredicateType | Acc], PredicateTypes)
     ).

implied_predicate_type(Predicate, Args, PredicateType) :-
    types_from_args(Args, Types),
    PredicateType =.. [predicate, Predicate, Types].

types_from_args([], []).
types_from_args([Arg | OtherArgs], [Type | OtherTypes]) :-
    type_from_arg(Arg, Type),
    types_from_args(OtherArgs, OtherTypes).

type_from_arg(object(Type, _), object_type(Type)) :- !.
type_from_arg(Value, Domain) :-
    domain_of(Value, Domain).

domain_of(Value, value_type(DomainName)) :-
    domain_is(DomainName, DomainValues),
    memberchk(Value, DomainValues), !.

extended_object_types(ObjectTypes, N, ExtendedObjectTypes) :-
    max_template_count_reached -> fail ; extended_object_types_(ObjectTypes, N, ExtendedObjectTypes).

extended_object_types_(ObjectTypes, 0, ObjectTypes).
extended_object_types_(ObjectTypes, N, ExtendedObjectTypes) :-
    N > 0,
    new_object_type(ObjectTypes, NewObjectType),
    N1 is N - 1,
    extended_object_types([NewObjectType | ObjectTypes], N1, ExtendedObjectTypes).

new_object_type(ObjectTypes, object_type(NewTypeName)) :-
    max_index(ObjectTypes, type_, 1, 0, Index),
    Index1 is Index + 1,
    atom_concat(type_, Index1, NewTypeName).

extended_objects(Objects, ObjectTypes, N, ExtendedObjects) :-
    max_template_count_reached -> fail ; extended_objects_(Objects, ObjectTypes, N, ExtendedObjects).

extended_objects_(Objects, _, 0, Objects).
extended_objects_(Objects, ObjectTypes, N, ExtendedObjects) :-
    N > 0,
    new_object(Objects, ObjectTypes, NewObject),
    N1 is N - 1,
    extended_objects([NewObject | Objects], ObjectTypes, N1, ExtendedObjects).

new_object(Objects, ObjectTypes, object(ObjectType, ObjectName)) :-
    member(object_type(ObjectType), ObjectTypes),
    max_index(Objects, object_, 2, 0, Index),
    Index1 is Index + 1,
    atom_concat(object_, Index1, ObjectName).

extended_predicate_types(PredicateTypes, ObjectTypes, N, ExtendedPredicateTypes) :-
    max_template_count_reached -> fail ; extended_predicate_types_(PredicateTypes, ObjectTypes, N, ExtendedPredicateTypes).

extended_predicate_types_(PredicateTypes, _, 0, PredicateTypes).
extended_predicate_types_(PredicateTypes, ObjectTypes, N, ExtendedPredicateTypes) :-
    N > 0,
    new_predicate_type(PredicateTypes, ObjectTypes, NewPredicateType),
    N1 is N - 1,
    % Append abducted predicates to favor predicates from min type signature in theory search
    append(PredicateTypes, [NewPredicateType], Acc),
    extended_predicate_types(Acc, ObjectTypes, N1, ExtendedPredicateTypes).

new_predicate_type(PredicateTypes, ObjectTypes, predicate(PredicateName, ArgumentTypes)) :-
    make_argument_types(ObjectTypes, ArgumentTypes),
    max_index(PredicateTypes, pred_, 1, 0, Index),
    Index1 is Index + 1,
    atom_concat(pred_, Index1, PredicateName).

% [variables(led, 2), variables(object1, 1)]
typed_variables(Objects, ObjectTypes, TypedVariables) :-
    typed_variables_(Objects, ObjectTypes, [], TypedVariables).

typed_variables_(_, [], TypedVariables, TypedVariables).
typed_variables_(Objects, [object_type(ObjectType) | OtherObjectTypes], Acc, TypedVariables) :-
    findall(ObjectName, member(object(ObjectType, ObjectName), Objects), ObjectNames),
    length(ObjectNames, Count),
    typed_variables_(Objects, OtherObjectTypes, [variables(ObjectType, Count) | Acc], TypedVariables).

% New (latent) predicates can only be of type object or boolean
make_argument_types(ObjectTypes, [ArgumentType1, ArgumentType2]) :-
    make_argument_type(ObjectTypes, ArgumentType1),
    make_argument_type(ObjectTypes, [boolean], ArgumentType2).

make_argument_type(ObjectTypes, ObjectType) :-
    member(ObjectType, ObjectTypes).

make_argument_type(ObjectTypes, _, ObjectType) :-
    make_argument_type(ObjectTypes, ObjectType).
make_argument_type(_, DomainTypes, value_type(DomainType)) :-
    member(DomainType, DomainTypes).

% Finds the maximum index used in a list of signature element, e.g nmax index is 2 in [object_type(type_1), object_type(type_2)]
max_index([], _, _, MaxIndex, MaxIndex).
max_index([Term | Others], Prefix, Position, Max, MaxIndex) :-
    Term =.. List,
    nth0(Position, List, IndexedAtom),
    atom_concat(Prefix, IndexAtom, IndexedAtom),
    atom_string(IndexAtom, IndexString),
    number_string(Index, IndexString),
    Max1 is max(Index, Max),
    !,
    max_index(Others, Prefix, Position, Max1, MaxIndex).

max_index([_ | Others], Prefix, Position, Max, MaxIndex) :-
    max_index(Others, Prefix, Position, Max, MaxIndex).

max_template_count_reached :-
    max_template_count_reached(Reached),
    Reached == true.

max_template_count_reached(Reached) :-
    catch(
        (
            engine_fetch(max_region_templates_reached(Reached)), 
            Reached == true ->
                log(warn, template_engine, "FETCHED max_region_templates_reached(~p)", [Reached])
        ),
        _,
        (
            log(debug, template_engine, "FAILED TO FETCH max_region_templates_reached/1"),
            Reached = false
        )
        ).

