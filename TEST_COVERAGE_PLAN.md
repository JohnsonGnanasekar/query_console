# Test Coverage Plan for QueryConsole v0.2.0

**Date:** January 16, 2026  
**Status:** 🔴 Needs Improvement (22 failing tests, missing tests for key components)

---

## 📊 Current Test Status

### Existing Tests ✅
1. **SqlValidator** - 29 examples (10 failing - needs fix)
2. **SqlLimiter** - 15 examples (all passing ✅)
3. **Runner** - 15 examples (2 failing - needs fix)
4. **ExplainRunner** - 15 examples (3 failing - needs fix)
5. **ExplainController** - 9 examples (7 failing - needs fix)

**Total:** 83 examples, 61 passing, 22 failing

---

## 🔴 Failing Tests (Priority: Fix First)

### 1. SqlValidator Tests (10 failures)
**Issue:** Tests expect error messages to include specific forbidden keywords (e.g., "UPDATE", "DELETE"), but queries that start with forbidden keywords get "Query must start with one of: SELECT, WITH" error instead.

**Solution:** Update test expectations to match actual error messages.

### 2. ExplainController Tests (7 failures)
**Issue:** Tests expect `response` to be successful, but getting non-successful responses (likely 404 or template errors).

**Solution:** Investigate template/routing issues, ensure test environment is properly configured.

### 3. Runner Tests (2 failures)
**Issue:** Same as SqlValidator - expecting specific keyword in error message.

**Solution:** Update test expectations.

### 4. ExplainRunner Tests (3 failures)
**Issue:** Tests expecting successful execution but getting failures.

**Solution:** Debug and fix, likely related to database setup or configuration.

---

## ❌ Missing Tests (Priority: Add After Fixing)

### Critical Missing Coverage

#### 1. QueriesController ⚠️ **HIGH PRIORITY**
**Status:** No tests exist  
**Lines:** ~50  
**Importance:** This is the MAIN controller for query execution

**Needs Tests For:**
- `GET /query_console` - renders new query page
- `POST /query_console/run` - executes queries
- Authorization checks
- Environment gating
- Validation errors
- Successful query execution  
- Timeout handling
- Audit logging
- Turbo Frame responses

**Estimated Examples:** 15-20

#### 2. SchemaController ⚠️ **HIGH PRIORITY**
**Status:** No tests exist  
**Lines:** ~40  
**Importance:** Core feature for schema exploration

**Needs Tests For:**
- `GET /schema/tables` - lists all tables
- `GET /schema/tables/:name` - show table details with columns
- Authorization checks
- Environment gating
- Error handling for nonexistent tables
- JSON response format

**Estimated Examples:** 10-12

#### 3. ApplicationController
**Status:** No tests exist  
**Lines:** ~30  
**Importance:** Base controller with authorization logic

**Needs Tests For:**
- Authorization check_access! method
- Environment gating check
- Audit actor extraction
- 404 responses when unauthorized
- 404 responses when environment not enabled

**Estimated Examples:** 8-10

#### 4. AuditLogger Service
**Status:** No tests exist  
**Lines:** ~40  
**Importance:** Critical for security audit trail

**Needs Tests For:**
- Log format (includes SQL, timestamp, actor, result)
- Success logging
- Failure logging  
- Actor extraction (email, IP, user agent)
- Rails logger integration
- Structured JSON output

**Estimated Examples:** 10-12

#### 5. SchemaIntrospector Service
**Status:** No tests exist  
**Lines:** ~60  
**Importance:** Core feature for schema exploration

**Needs Tests For:**
- List all tables
- Get table details with columns
- Column metadata (name, type, nullable, default)
- Primary key detection
- Table kind (table vs view)
- Error handling for nonexistent tables
- Different database adapters (SQLite, PostgreSQL, MySQL)

**Estimated Examples:** 12-15

#### 6. Configuration
**Status:** No tests exist  
**Lines:** ~80  
**Importance:** Validates gem configuration

**Needs Tests For:**
- Default configuration values
- Custom configuration  
- `authorize` lambda
- `current_actor` lambda
- `enabled_environments`
- `max_rows` limits
- `timeout_ms`
- `allowed_starts_with`
- `forbidden_keywords`
- `enable_explain` flag
- `enable_explain_analyze` flag
- Configuration reset

**Estimated Examples:** 15-18

#### 7. Engine
**Status:** No tests exist  
**Lines:** ~20  
**Importance:** Validates gem loading

**Needs Tests For:**
- Engine loads correctly
- Routes mount properly
- Configuration accessible
- Helpers available

**Estimated Examples:** 5-6

---

## 🎯 Test Coverage Goals

### Target Coverage: 90%+

**Current Estimated Coverage:** ~45%  
**Target Coverage:** 90%+

### Coverage by Component Type

| Component Type | Current | Target |
|----------------|---------|--------|
| Controllers | ~30% (1/3 tested) | 100% (3/3 tested) |
| Services | ~67% (4/6 tested) | 100% (6/6 tested) |
| Configuration | 0% | 100% |
| Engine | 0% | 100% |
| **Overall** | **~45%** | **90%+** |

---

## 📝 Test Priority Order

### Phase 1: Fix Existing Tests (URGENT)
1. ✅ Fix SqlValidator test expectations
2. ✅ Fix ExplainController test environment
3. ✅ Fix Runner test expectations  
4. ✅ Fix ExplainRunner database issues

**Estimated Time:** 1-2 hours  
**Goal:** 83/83 tests passing

### Phase 2: Critical Missing Tests (HIGH PRIORITY)
1. ✅ Add QueriesController tests
2. ✅ Add SchemaController tests
3. ✅ Add ApplicationController tests

**Estimated Time:** 2-3 hours  
**Goal:** ~140 tests total, all passing

### Phase 3: Service Tests (MEDIUM PRIORITY)
1. ✅ Add AuditLogger tests
2. ✅ Add SchemaIntrospector tests

**Estimated Time:** 1-2 hours  
**Goal:** ~165 tests total

### Phase 4: Configuration & Engine (LOW PRIORITY)
1. ✅ Add Configuration tests
2. ✅ Add Engine tests

**Estimated Time:** 1 hour  
**Goal:** ~185 tests total

---

## 🧪 Test Quality Standards

All tests must follow these standards:

### Structure
- Clear context blocks
- Descriptive test names
- Proper setup/teardown
- Use `let` for test data
- DRY test code

### Coverage
- Happy path scenarios
- Error cases
- Edge cases
- Security validations
- Authorization checks
- Environment gating

### Performance
- Fast execution (<5 seconds total)
- Use transactions for cleanup
- Mock external dependencies
- No sleep/wait calls

### Maintainability
- Clear failure messages
- Easy to debug
- Self-documenting
- Follows RSpec best practices

---

## 📦 Test Tools & Setup

### Current Setup
- **Framework:** RSpec 3.x
- **Rails Testing:** RSpec Rails
- **Database:** SQLite (test environment)
- **Coverage Tool:** None (should add SimpleCov)

### Recommended Additions
1. **SimpleCov** - Code coverage reporting
2. **FactoryBot** - Test data factories
3. **Faker** - Fake data generation
4. **Database Cleaner** - Better test isolation

---

## 🚦 Success Criteria

### Phase 1 Complete ✅
- [ ] All 83 existing tests passing
- [ ] No deprecation warnings
- [ ] Fast execution (<5s)

### Phase 2 Complete ✅
- [ ] QueriesController fully tested
- [ ] SchemaController fully tested  
- [ ] ApplicationController fully tested
- [ ] ~140 total tests passing

### Phase 3 Complete ✅
- [ ] AuditLogger fully tested
- [ ] SchemaIntrospector fully tested
- [ ] ~165 total tests passing

### Phase 4 Complete ✅
- [ ] Configuration fully tested
- [ ] Engine fully tested
- [ ] ~185 total tests passing
- [ ] 90%+ code coverage
- [ ] SimpleCov reports added
- [ ] All tests green

---

## 📊 Test Metrics

### Current Metrics
```
Total Examples: 83
Passing: 61 (73%)
Failing: 22 (27%)
Coverage: ~45% (estimated)
Execution Time: ~0.1s
```

### Target Metrics
```
Total Examples: 185+
Passing: 185+ (100%)
Failing: 0 (0%)
Coverage: 90%+
Execution Time: <5s
```

---

## 💡 Testing Best Practices for Contributors

1. **Write tests first** - TDD approach
2. **Test behavior, not implementation** - Focus on outcomes
3. **One assertion per test** - When possible
4. **Use descriptive names** - Test names should read like documentation
5. **Test edge cases** - Empty strings, nil, very long inputs
6. **Test security** - SQL injection, unauthorized access
7. **Keep tests fast** - Use transactions, mock slow operations
8. **Don't test Rails** - Focus on your code, not the framework
9. **Use shared examples** - For common patterns
10. **Document complex tests** - Add comments for tricky setups

---

## 📋 Checklist for Adding New Features

When adding a new feature, ensure:

- [ ] Unit tests for new services/models
- [ ] Controller tests for new endpoints
- [ ] Integration tests for user flows
- [ ] Security tests (authorization, SQL injection)
- [ ] Error handling tests
- [ ] Edge case tests
- [ ] Documentation updated
- [ ] CHANGELOG updated
- [ ] All tests passing
- [ ] Coverage maintained at 90%+

---

## 🆘 Test Maintenance

### When Tests Fail
1. Run single failing test: `bundle exec rspec spec/path/to/spec.rb:LINE`
2. Check error message carefully
3. Verify test assumptions are still valid
4. Update test if implementation changed correctly
5. Fix implementation if test is correct

### Regular Maintenance
- Run full suite weekly: `bundle exec rspec`
- Check for deprecation warnings
- Update test dependencies
- Review and improve slow tests
- Add tests for reported bugs

---

## 📚 Resources

- [RSpec Documentation](https://rspec.info/)
- [RSpec Rails](https://github.com/rspec/rspec-rails)
- [Better Specs](https://www.betterspecs.org/)
- [Testing Rails](https://testingrailsbook.com/)

---

**Last Updated:** January 16, 2026  
**Next Review:** After Phase 1 completion
