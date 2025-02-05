import RxSwift

extension ObservableType {
    func mapToVoid() -> Observable<Void> {
        return map { _ in () }
    }
} 