#import "Kiwi.h"
#import "Person+Mappings.h"
#import "Car+Mappings.h"
#import "InsuranceCompany.h"

SPEC_BEGIN(MappingsTests)

describe(@"Mappings", ^{
    
    NSDictionary *JSON = @{
        @"first_name": @"Marin",
        @"last_name": @"Usalj",
        @"age": @25,
        @"is_member": @"true",
        @"profile": @{
                @"role": @"CEO",
                @"life_savings": @1500.12,
                },
        @"cars": @[
               @{ @"hp": @220, @"make": @"Trabant" },
               @{ @"hp": @90, @"make": @"Volkswagen" }
        ],
        @"manager": @{
               @"firstName": @"Delisa",
               @"lastName": @"Mason",
               @"age": @25,
               @"isMember": @NO
        },
        @"employees": @[
               @{ @"first_name": @"Luca" },
               @{ @"first_name": @"Tony" },
               @{ @"first_name": @"Jim" }
        ]
    };
    
    __block Person *person;
    
    NSManagedObjectContext *newContext = [[NSManagedObjectContext alloc] initWithConcurrencyType:NSPrivateQueueConcurrencyType];
    newContext.persistentStoreCoordinator = [[CoreDataManager sharedManager] persistentStoreCoordinator];
    
    beforeEach(^{
        person = [Person create:JSON inContext:newContext];
    });
    
    it(@"caches mappings", ^{
        Car *car = [Car createInContext:newContext];
        [[Car should] receive:@selector(mappings) withCountAtMost:1];
        
        [car update:@{ @"hp": @150 }];
        [car update:@{ @"make": @"Ford" }];
        [car update:@{ @"hp": @150 }];
    });
    
    it(@"supports keypath nested property mappings", ^{
        Person *person = [Person createInContext:newContext];
        [[Person should] receive:@selector(mappings) withCountAtMost:1];
        [[Person should] receive:@selector(keyPathForRemoteKey:) withCountAtMost:1];
        
        [person update:@{ @"first_name": @"Marin", @"last_name": @"Usalj" }];
        [person update:@{ @"profile": @{ @"role": @"CEO", @"life_savings": @1500.12 } }];
    });
    
    it(@"uses mapped values when creating", ^{
        [[person.firstName should] equal:@"Marin"];
        [[person.lastName should] equal:@"Usalj"];
        [[person.age should] equal:@25];
    });
    
    it(@"can support snake_case even without mappings", ^{
        [[person.isMember should] beTrue];
    });
    
    it(@"supports nested properties", ^{
        [[[person should] have:2] cars];
    });
    
    it(@"supports to one relationship", ^{
        [[person.manager.firstName should] equal:@"Delisa"];
    });
    
    it(@"supports to many relationship", ^{
       [[[person should] have:3] employees];
    });
    
    it(@"uses mappings in findOrCreate", ^{
        Person *bob = [Person findOrCreate:@{ @"first_name": @"Bob" }];
        [[bob.firstName should] equal:@"Bob"];
    });
    
    it(@"supports creating a parent object using just ID from the server", ^{
        Car *car = [Car create:@{ @"hp": @150, @"insurance_id": @1234 }];
        [[car.insuranceCompany should] equal:[InsuranceCompany find:@{ @"remoteID": @1234 }]];
    });

    it(@"supports creating nested objects directly", ^{
        Person *employee = [Person create];
        Person *manager = [Person create:@{@"employees": @[employee]}];
        [[[manager should] have:1] employees];
    });

    it(@"ignores unknown keys", ^{
        Car *car = [Car create];
        [[car shouldNot] receive:@selector(setPrimitiveValue:forKey:)];
        [car update:@{ @"chocolate": @"waffles" }];
    });

    it(@"ignores embedded unknown keys", ^{
        [[theBlock(^{
            Car *car = [Car create];
            [car update:@{ @"owner": @{ @"coolness": @(100) } }];
        }) shouldNot] raise];
    });

    it(@"supports creating nested parent objects using IDs from the server", ^{
        Car *car = [Car create:@{ @"insurance_company": @{ @"id" : @1234, @"owner_id" : @4567 }}];
        [[car.insuranceCompany.owner should] equal:[Person find:@{ @"remoteID": @4567 }]];
    });

    it(@"supports creating full nested parent objects", ^{
        Car *car = [Car create:@{ @"insurance_company": @{ @"id" : @1234, @"owner" : @{ @"id" : @4567, @"first_name" : @"Stan" } }}];
        [[car.insuranceCompany.owner should] equal:[Person find:@{ @"remoteID": @4567, @"firstName": @"Stan" }]];
    });
});

SPEC_END
