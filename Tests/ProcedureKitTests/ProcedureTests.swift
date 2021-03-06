//
//  ProcedureKit
//
//  Copyright © 2016 ProcedureKit. All rights reserved.
//

import XCTest
import TestingProcedureKit
@testable import ProcedureKit

class QueueDelegateTests: ProcedureKitTestCase {

    func test__delegate__operation_notifications() {

        weak var expAddFinished = expectation(description: "Test: \(#function), queue.add did finish")
        weak var expOperationFinished = expectation(description: "Test: \(#function), Operation did finish")
        let operation = BlockOperation { }
        let finishedOperation = BlockProcedure { }
        finishedOperation.addDependency(operation)
        finishedOperation.addDidFinishBlockObserver { _, _ in
            DispatchQueue.main.async {
                expOperationFinished?.fulfill()
            }
        }

        queue.add(operations: [operation, finishedOperation]).then(on: DispatchQueue.main) {
            expAddFinished?.fulfill()
        }
        waitForExpectations(timeout: 3)

        XCTAssertFalse(delegate.procedureQueueWillAddOperation.isEmpty)
        XCTAssertFalse(delegate.procedureQueueDidAddOperation.isEmpty)
        XCTAssertFalse(delegate.procedureQueueDidFinishOperation.isEmpty)
    }

    func test___delegate__procedure_notifications() {

        weak var expAddFinished = expectation(description: "Test: \(#function), queue.add did finish")
        addCompletionBlockTo(procedure: procedure)

        queue.add(operation: procedure).then(on: DispatchQueue.main) {
            expAddFinished?.fulfill()
        }
        waitForExpectations(timeout: 3)

        XCTAssertFalse(delegate.procedureQueueWillAddProcedure.isEmpty)
        XCTAssertFalse(delegate.procedureQueueDidAddProcedure.isEmpty)
        XCTAssertFalse(delegate.procedureQueueWillFinishProcedure.isEmpty)
        XCTAssertFalse(delegate.procedureQueueDidFinishProcedure.isEmpty)
    }

    func test__delegate__operationqueue_addoperation() {
        // Testing OperationQueue's
        // `open func addOperation(_ op: Operation)`
        // on a ProcedureQueue to ensure that it goes through the
        // overriden ProcedureQueue add path.
        
        weak var didExecuteOperation = expectation(description: "Test: \(#function), did execute block")
        queue.addOperation( BlockOperation{
            DispatchQueue.main.async {
                didExecuteOperation?.fulfill()
            }
        })
        
        waitForExpectations(timeout: 3)
        
        XCTAssertFalse(delegate.procedureQueueWillAddOperation.isEmpty)
        XCTAssertFalse(delegate.procedureQueueDidAddOperation.isEmpty)
        XCTAssertFalse(delegate.procedureQueueDidFinishOperation.isEmpty)
    }

    func test__delegate__operationqueue_addoperation_waituntilfinished() {
        // Testing OperationQueue's
        // `open func addOperations(_ ops: [Operation], waitUntilFinished wait: Bool)`
        // on a ProcedureQueue to ensure that it goes through the
        // overriden ProcedureQueue add path and that it *doesn't* wait.
        
        weak var didExecuteOperation = expectation(description: "Test: \(#function), Operation did finish without being waited on by addOperations(_:waitUntilFinished:)")
        let operationCanProceed = DispatchSemaphore(value: 0)
        let operation = BlockOperation{
            guard operationCanProceed.wait(timeout: .now() + 1.0) == .success else {
                // do not fulfill expectation, because main never signaled that this
                // operation can proceed
                return
            }
            DispatchQueue.main.async {
                didExecuteOperation?.fulfill()
            }
        }
        queue.addOperations([operation], waitUntilFinished: true)
        operationCanProceed.signal()

        waitForExpectations(timeout: 2)

        XCTAssertFalse(delegate.procedureQueueWillAddOperation.isEmpty)
        XCTAssertFalse(delegate.procedureQueueDidAddOperation.isEmpty)
        XCTAssertFalse(delegate.procedureQueueDidFinishOperation.isEmpty)
    }
    
    func test__delegate__operationqueue_addoperation_block() {
        // Testing OperationQueue's
        // `open func addOperation(_ block: @escaping () -> Swift.Void)`
        // on a ProcedureQueue to ensure that it goes through the
        // overriden ProcedureQueue add path.

        weak var didExecuteBlock = expectation(description: "Test: \(#function), did execute block")
        queue.addOperation({
            DispatchQueue.main.async {
                didExecuteBlock?.fulfill()
            }
        })

        waitForExpectations(timeout: 3)

        XCTAssertFalse(delegate.procedureQueueWillAddOperation.isEmpty)
        XCTAssertFalse(delegate.procedureQueueDidAddOperation.isEmpty)
        XCTAssertFalse(delegate.procedureQueueDidFinishOperation.isEmpty)
    }
}

class ExecutionTests: ProcedureKitTestCase {

    func test__procedure_executes() {
        wait(for: procedure)
        XCTAssertTrue(procedure.didExecute)
    }

    func test__procedure_add_multiple_completion_blocks() {
        weak var expect = expectation(description: "Test: \(#function), \(UUID())")

        var completionBlockOneDidRun = 0
        procedure.addCompletionBlock {
            completionBlockOneDidRun += 1
        }

        var completionBlockTwoDidRun = 0
        procedure.addCompletionBlock {
            completionBlockTwoDidRun += 1
        }

        var finalCompletionBlockDidRun = 0
        procedure.addCompletionBlock {
            finalCompletionBlockDidRun += 1
            DispatchQueue.main.async {
                guard let expect = expect else { print("Test: \(#function): Finished expectation after timeout"); return }
                expect.fulfill()
            }
        }

        wait(for: procedure)

        XCTAssertEqual(completionBlockOneDidRun, 1)
        XCTAssertEqual(completionBlockTwoDidRun, 1)
        XCTAssertEqual(finalCompletionBlockDidRun, 1)
    }

    func test__enqueue_a_sequence_of_operations() {
        addCompletionBlockTo(procedure: procedure, withExpectationDescription: "\(#function)")
        [procedure].enqueue()
        waitForExpectations(timeout: 3, handler: nil)
        XCTAssertProcedureFinishedWithoutErrors()
    }

    func test__enqueue_a_sequence_of_operations_deallocates_queue() {
        addCompletionBlockTo(procedure: procedure, withExpectationDescription: "\(#function)")
        var nilQueue: ProcedureQueue! = ProcedureQueue()
        weak var weakQueue = nilQueue
        [procedure].enqueue(on: weakQueue!)
        nilQueue = nil
        waitForExpectations(timeout: 3, handler: nil)
        XCTAssertNil(nilQueue)
        XCTAssertNil(weakQueue)
    }
}

class UserIntentTests: ProcedureKitTestCase {

    func test__getting_user_intent_default_background() {
        XCTAssertEqual(procedure.userIntent, .none)
    }

    func test__set_user_intent__initiated() {
        procedure.userIntent = .initiated
        XCTAssertEqual(procedure.qualityOfService, .userInitiated)
    }

    func test__set_user_intent__side_effect() {
        procedure.userIntent = .sideEffect
        XCTAssertEqual(procedure.qualityOfService, .userInitiated)
    }

    func test__set_user_intent__initiated_then_background() {
        procedure.userIntent = .initiated
        procedure.userIntent = .none
        XCTAssertEqual(procedure.qualityOfService, .default)
    }

    func test__user_intent__equality() {
        XCTAssertNotEqual(UserIntent.initiated, UserIntent.sideEffect)
    }
}

import Dispatch

class QualityOfServiceTests: ProcedureKitTestCase {

    private func testQoSClassLevels(_ block: (QualityOfService) -> Void) {
        block(.userInteractive)
        block(.userInitiated)
        block(.utility)
        block(.background)
        block(.`default`)
    }

    func test__procedure__set_quality_of_service__procedure_execute() {
        testQoSClassLevels { desiredQoS in
            let recordedQoSClass = Protector<DispatchQoS.QoSClass>(.unspecified)
            let procedure = BlockProcedure {
                recordedQoSClass.overwrite(with: DispatchQueue.currentQoSClass)
            }
            procedure.qualityOfService = desiredQoS
            wait(for: procedure)
            XCTAssertEqual(recordedQoSClass.access, desiredQoS.qosClass)
        }
    }

    func test__procedure__set_quality_of_service__will_execute_observer() {
        testQoSClassLevels { desiredQoS in
            let recordedQoSClass = Protector<DispatchQoS.QoSClass>(.unspecified)
            let procedure = TestProcedure()
            procedure.addWillExecuteBlockObserver { procedure, _ in
                recordedQoSClass.overwrite(with: DispatchQueue.currentQoSClass)
            }
            procedure.qualityOfService = desiredQoS
            wait(for: procedure)
            XCTAssertEqual(recordedQoSClass.access, desiredQoS.qosClass)
        }
    }

    func test__procedure__set_quality_of_service__execute_after_will_execute_on_custom_queue() {
        testQoSClassLevels { desiredQoS in
            let recordedQoSClass_willExecute_otherQueue = Protector<DispatchQoS.QoSClass>(.unspecified)
            let recordedQoSClass_willExecute = Protector<DispatchQoS.QoSClass>(.unspecified)
            let recordedQoSClass_execute = Protector<DispatchQoS.QoSClass>(.unspecified)
            let procedure = BlockProcedure {
                recordedQoSClass_execute.overwrite(with: DispatchQueue.currentQoSClass)
            }
            // 1st WillExecute observer has a custom queue with no specified QoS level
            // the submitted observer block should run with a QoS at least that of the desiredQoS level
            let otherQueue = DispatchQueue(label: "run.kit.procedure.ProcedureKit.Testing.OtherQueue")
            procedure.addWillExecuteBlockObserver(synchronizedWith: otherQueue) { procedure, _ in
                recordedQoSClass_willExecute_otherQueue.overwrite(with: DispatchQueue.currentQoSClass)
            }
            // 2nd WillExecute observer has no custom queue (runs on the Procedure's EventQueue)
            // the observer block should run with a QoS level equal to the desiredQoS level
            procedure.addWillExecuteBlockObserver { procedure, _ in
                recordedQoSClass_willExecute.overwrite(with: DispatchQueue.currentQoSClass)
            }
            procedure.qualityOfService = desiredQoS
            wait(for: procedure)
            XCTAssertGreaterThanOrEqual(recordedQoSClass_willExecute_otherQueue.access, desiredQoS.qosClass)
            XCTAssertEqual(recordedQoSClass_willExecute.access, desiredQoS.qosClass)
            XCTAssertEqual(recordedQoSClass_execute.access, desiredQoS.qosClass)
        }
    }

    func test__procedure__set_quality_of_service__did_cancel_observer() {
        testQoSClassLevels { desiredQoS in
            weak var expDidCancel = expectation(description: "did cancel Procedure with qualityOfService: \(desiredQoS.qosClass)")
            let recordedQoSClass = Protector<DispatchQoS.QoSClass>(.unspecified)
            let procedure = TestProcedure()
            procedure.addDidCancelBlockObserver { procedure, _ in
                recordedQoSClass.overwrite(with: DispatchQueue.currentQoSClass)
                DispatchQueue.main.async { expDidCancel?.fulfill() }
            }
            procedure.qualityOfService = desiredQoS
            procedure.cancel()
            waitForExpectations(timeout: 3)
            // DidCancel observers should be executed with the qualityOfService of the Procedure
            XCTAssertEqual(recordedQoSClass.access, desiredQoS.qosClass)
        }
    }
}

class ProcedureTests: ProcedureKitTestCase {

    func test__procedure_name() {
        let block = BlockProcedure { }
        XCTAssertEqual(block.name, "BlockProcedure")

        let group = GroupProcedure(operations: [])
        XCTAssertEqual(group.name, "GroupProcedure")
    }

    func test__identity_is_equatable() {
        let identity1 = procedure.identity
        let identity2 = procedure.identity
        XCTAssertEqual(identity1, identity2)
    }

    func test__identity_description() {
        XCTAssertTrue(procedure.identity.description.hasPrefix("TestProcedure #"))
        procedure.name = nil
        XCTAssertTrue(procedure.identity.description.hasPrefix("Unnamed Procedure #"))
    }
}

class DependencyTests: ProcedureKitTestCase {

    func test__operation_added_using_then_follows_receiver() {
        let another = TestProcedure()
        let operations = procedure.then(do: another)
        XCTAssertEqual(operations, [procedure, another])
        wait(for: procedure, another)
        XCTAssertLessThan(procedure.executedAt, another.executedAt)
    }

    func test__operation_added_using_then_via_closure_follows_receiver() {
        let another = TestProcedure()
        let operations = procedure.then { another }
        XCTAssertEqual(operations, [procedure, another])
        wait(for: procedure, another)
        XCTAssertLessThan(procedure.executedAt, another.executedAt)
    }

    func test__operation_added_using_then_via_closure_returning_nil() {
        XCTAssertEqual(procedure.then { nil }, [procedure])
    }

    func test__operation_added_using_then_via_closure_throwing_error() {
        do {
            let _ = try procedure.then { throw TestError() }
        }
        catch is TestError { }
        catch { XCTFail("Caught unexpected error.") }
    }

    func test__operation_added_to_array_using_then() {
        let one = TestProcedure()
        let two = TestProcedure(delay: 1)
        let another = TestProcedure()
        let all = [one, two, procedure].then(do: another)
        XCTAssertEqual(all.count, 4)
        wait(for: one, two, procedure, another)
        XCTAssertProcedureFinishedWithoutErrors(another)
        XCTAssertLessThan(one.executedAt, another.executedAt)
        XCTAssertLessThan(two.executedAt, another.executedAt)
        XCTAssertLessThan(procedure.executedAt, another.executedAt)
    }

    func test__operation_added_to_array_using_then_via_closure() {
        let one = TestProcedure()
        let two = TestProcedure(delay: 1)
        let another = TestProcedure()
        let all = [one, two, procedure].then { another }
        XCTAssertEqual(all.count, 4)
        wait(for: one, two, procedure, another)
        XCTAssertProcedureFinishedWithoutErrors(another)
        XCTAssertLessThan(one.executedAt, another.executedAt)
        XCTAssertLessThan(two.executedAt, another.executedAt)
        XCTAssertLessThan(procedure.executedAt, another.executedAt)
    }

    func test__operation_added_to_array_using_then_via_closure_throwing_error() {
        let one = TestProcedure()
        let two = TestProcedure(delay: 1)
        do {
            let _ = try [one, two, procedure].then { throw TestError() }
        }
        catch is TestError { }
        catch { XCTFail("Caught unexpected error.") }
    }

    func test__operation_added_to_array_using_then_via_closure_returning_nil() {
        let one = TestProcedure()
        let two = TestProcedure(delay: 1)
        let all = [one, two, procedure].then { nil }
        XCTAssertEqual(all.count, 3)
    }
}

class ProduceTests: ProcedureKitTestCase {

    func test__procedure_produce_operation() {
        LogManager.severity = .verbose
        let producedOperation = BlockProcedure { usleep(5000) }
        producedOperation.name = "ProducedOperation"
        addCompletionBlockTo(procedure: producedOperation)
        let procedure = EventConcurrencyTrackingProcedure() { procedure in
            try! procedure.produce(operation: producedOperation) // swiftlint:disable:this force_try
            procedure.finish()
        }
        wait(for: procedure)
        XCTAssertProcedureFinishedWithoutErrors(producedOperation)
        XCTAssertProcedureFinishedWithoutErrors(procedure)
        XCTAssertProcedureNoConcurrentEvents(procedure)
    }

    func test__procedure_produce_operation_before_execute() {
        LogManager.severity = .verbose
        let producedOperation = BlockProcedure { usleep(5000) }
        producedOperation.name = "ProducedOperation"
        let procedure = EventConcurrencyTrackingProcedure() { procedure in
            procedure.finish()
        }
        procedure.addWillExecuteBlockObserver { procedure, pendingExecute in
            try! procedure.produce(operation: producedOperation, before: pendingExecute) // swiftlint:disable:this force_try
        }
        wait(for: procedure)
        XCTAssertProcedureFinishedWithoutErrors(producedOperation)
        XCTAssertProcedureFinishedWithoutErrors(procedure)
        XCTAssertProcedureNoConcurrentEvents(procedure)
    }

    func test__procedure_produce_operation_before_execute_async() {
        var didExecuteWillAddObserverForProducedOperation = false
        var procedureIsExecuting_InWillAddObserver = false
        var procedureIsFinished_InWillAddObserver = false

        let producedOperation = BlockProcedure { usleep(5000) }
        producedOperation.name = "ProducedOperation"
        let procedure = EventConcurrencyTrackingProcedure() { procedure in
            procedure.finish()
        }
        procedure.addWillExecuteBlockObserver { procedure, pendingExecute in
            DispatchQueue.global().asyncAfter(deadline: .now() + 0.5) {
                // despite this being executed long after the willExecute observer has returned
                // (and a delay), by passing the pendingExecute event to the produce function
                // it should ensure that `procedure` does not execute until producing the
                // operation succeeds (i.e. until all WillAdd observers have been fired and it's
                // added to the queue)
                try! procedure.produce(operation: producedOperation, before: pendingExecute) // swiftlint:disable:this force_try
            }
        }
        procedure.addWillAddOperationBlockObserver { procedure, operation in
            guard operation === producedOperation else { return }
            didExecuteWillAddObserverForProducedOperation = true
            procedureIsExecuting_InWillAddObserver = procedure.isExecuting
            procedureIsFinished_InWillAddObserver = procedure.isFinished
        }
        wait(for: procedure)
        XCTAssertProcedureFinishedWithoutErrors(producedOperation)
        XCTAssertProcedureFinishedWithoutErrors(procedure)
        XCTAssertTrue(didExecuteWillAddObserverForProducedOperation, "procedure never executed its WillAddOperation observer for the produced operation")
        XCTAssertFalse(procedureIsExecuting_InWillAddObserver, "procedure was executing when its WillAddOperation observer was fired for the produced operation")
        XCTAssertFalse(procedureIsFinished_InWillAddObserver, "procedure was finished when its WillAddOperation observer was fired for the produced operation")
    }

    func test__procedure_produce_operation_before_finish() {
        LogManager.severity = .verbose
        let producedOperation = BlockProcedure { usleep(5000) }
        producedOperation.name = "ProducedOperation"
        let procedure = EventConcurrencyTrackingProcedure() { procedure in
            procedure.finish()
        }
        procedure.addWillFinishBlockObserver { procedure, errors, pendingFinish in
            try! procedure.produce(operation: producedOperation, before: pendingFinish) // swiftlint:disable:this force_try
        }
        wait(for: procedure)
        XCTAssertProcedureFinishedWithoutErrors(producedOperation)
        XCTAssertProcedureFinishedWithoutErrors(procedure)
    }

    func test__procedure_produce_operation_before_finish_async() {
        var didExecuteWillAddObserverForProducedOperation = false
        var procedureIsExecuting_InWillAddObserver = false
        var procedureIsFinished_InWillAddObserver = false

        let producedOperation = BlockProcedure { usleep(5000) }
        producedOperation.name = "ProducedOperation"
        let procedure = EventConcurrencyTrackingProcedure() { procedure in
            procedure.finish()
        }
        procedure.addWillFinishBlockObserver { procedure, errors, pendingFinish in
            DispatchQueue.global().asyncAfter(deadline: .now() + 0.5) {
                // despite this being executed long after the willFinish observer has returned
                // (and a delay), by passing the pendingFinish event to the produce function
                // it should ensure that `procedure` does not finish until producing the
                // operation succeeds (i.e. until all WillAdd observers have been fired and it's
                // added to the queue)
                try! procedure.produce(operation: producedOperation, before: pendingFinish) // swiftlint:disable:this force_try
            }
        }
        procedure.addWillAddOperationBlockObserver { procedure, operation in
            guard operation === producedOperation else { return }
            didExecuteWillAddObserverForProducedOperation = true
            procedureIsExecuting_InWillAddObserver = procedure.isExecuting
            procedureIsFinished_InWillAddObserver = procedure.isFinished
        }
        wait(for: procedure)
        XCTAssertProcedureFinishedWithoutErrors(producedOperation)
        XCTAssertProcedureFinishedWithoutErrors(procedure)
        XCTAssertTrue(didExecuteWillAddObserverForProducedOperation, "procedure never executed its WillAddOperation observer for the produced operation")
        XCTAssertFalse(procedureIsExecuting_InWillAddObserver, "procedure was executing when its WillAddOperation observer was fired for the produced operation")
        XCTAssertFalse(procedureIsFinished_InWillAddObserver, "procedure was finished when its WillAddOperation observer was fired for the produced operation")
    }
}

class ObserverEventQueueTests: ProcedureKitTestCase {

    func test__custom_observer_with_event_queue() {
        let didFinishGroup = DispatchGroup()
        didFinishGroup.enter()
        let eventsNotOnSpecifiedQueue = Protector<[EventConcurrencyTrackingRegistrar.ProcedureEvent]>([])
        let eventsOnSpecifiedQueue = Protector<[EventConcurrencyTrackingRegistrar.ProcedureEvent]>([])
        let registrar = EventConcurrencyTrackingRegistrar()
        let customEventQueue = EventQueue(label: "run.kit.procedure.ProcedureKit.Testing.ObserverCustomEventQueue")
        let observer = ConcurrencyTrackingObserver(registrar: registrar, eventQueue: customEventQueue, callbackBlock: { procedure, event in
            guard customEventQueue.isOnQueue else {
                eventsNotOnSpecifiedQueue.append(event)//((procedure.operationName, event))
                return
            }
            eventsOnSpecifiedQueue.append(event)//((procedure.operationName, event))
        })
        let procedure = EventConcurrencyTrackingProcedure(name: "TestingProcedure") { procedure in
            procedure.finish()
        }
        procedure.add(observer: observer)
        procedure.addDidFinishBlockObserver { _, _ in
            didFinishGroup.leave()
        }

        let finishing = BlockProcedure { }
        finishing.addDependency(procedure)

        run(operation: procedure)
        wait(for: finishing)

        // Because Procedure signals isFinished KVO *prior* to calling DidFinish observers,
        // the above wait() may return before the ConcurrencyTrackingObserver is called to
        // record the DidFinish event.
        // Thus, wait on a second observer added *after* the ConcurrencyTrackingObserver
        // to ensure the event is captured by this test.
        weak var expDidFinishObserverFired = expectation(description: "DidFinishObserver was fired")
        didFinishGroup.notify(queue: DispatchQueue.main) {
            expDidFinishObserverFired?.fulfill()
        }
        waitForExpectations(timeout: 2)

        XCTAssertTrue(eventsNotOnSpecifiedQueue.access.isEmpty, "Found events not on expected queue: \(eventsNotOnSpecifiedQueue.access)")

        let expectedEventsOnQueue: [EventConcurrencyTrackingRegistrar.ProcedureEvent] = [.observer_didAttach, .observer_willExecute, .observer_didExecute, .observer_willFinish, .observer_didFinish]

        XCTAssertEqual(eventsOnSpecifiedQueue.access, expectedEventsOnQueue)
    }

    func test__custom_observer_with_event_queue_same_as_self() {
        let procedure = EventConcurrencyTrackingProcedure(name: "TestingProcedure") { procedure in
            procedure.finish()
        }

        let registrar = EventConcurrencyTrackingRegistrar()
        // NOTE: Don't do this. This is just for testing.
        let observer = ConcurrencyTrackingObserver(registrar: registrar, eventQueue: procedure.eventQueue)
        procedure.add(observer: observer)

        let finishing = BlockProcedure { }
        finishing.addDependency(procedure)

        run(operation: procedure)
        wait(for: finishing) // This test should not timeout.
    }
}
