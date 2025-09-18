//
//  Copyright © Essential Developer. All rights reserved.
//

import CoreData

public final class CoreDataFeedStore: FeedStore {
	public static let modelName = "FeedStore"
	public static let model = NSManagedObjectModel(name: modelName, in: Bundle(for: CoreDataFeedStore.self))

	private let container: NSPersistentContainer
	private let context: NSManagedObjectContext

	public struct ModelNotFound: Error {
		public let modelName: String
	}

	public init(storeURL: URL) throws {
		guard let model = CoreDataFeedStore.model else {
			throw ModelNotFound(modelName: CoreDataFeedStore.modelName)
		}

		container = try NSPersistentContainer.load(
			name: CoreDataFeedStore.modelName,
			model: model,
			url: storeURL
		)
		context = container.newBackgroundContext()
	}

	deinit {
		cleanUpReferencesToPersistentStores()
	}

	private func cleanUpReferencesToPersistentStores() {
		context.performAndWait {
			let coordinator = self.container.persistentStoreCoordinator
			try? coordinator.persistentStores.forEach(coordinator.remove)
		}
	}

	public func retrieve(completion: @escaping RetrievalCompletion) {
		let context = self.context
		context.perform {
			do {
				if let managedCache = try ManagedCache.find(context: context) {
					completion(.found(feed: managedCache.localFeed, timestamp: managedCache.timestamp))
				} else {
					completion(.empty)
				}

			} catch {
				completion(.failure(error))
			}
		}
	}

	public func insert(_ feed: [LocalFeedImage], timestamp: Date, completion: @escaping InsertionCompletion) {
		let context = self.context
		context.perform {
			do {
				let managedCache = try ManagedCache.newUniqueInstance(context: context)
				managedCache.timestamp = timestamp
				managedCache.feed = ManagedFeedImage.feedImage(feed, context)

				try context.save()

				completion(nil)

			} catch {
				context.rollback()

				completion(error)
			}
		}
	}

	public func deleteCachedFeed(completion: @escaping DeletionCompletion) {
		let context = self.context
		context.perform {
			do {
				try ManagedCache.find(context: context).map(context.delete)

				try context.save()

				completion(nil)

			} catch {
				context.rollback()

				completion(error)
			}
		}
	}
}

extension CoreDataFeedStore {
	@objc(ManagedCache)
	private class ManagedCache: NSManagedObject {
		@NSManaged var timestamp: Date
		@NSManaged var feed: NSOrderedSet

		var localFeed: [LocalFeedImage] {
			return feed.compactMap { ($0 as? ManagedFeedImage)?.local }
		}

		static func find(context: NSManagedObjectContext) throws -> ManagedCache? {
			let request = NSFetchRequest<ManagedCache>(entityName: ManagedCache.entity().name!)
			request.returnsObjectsAsFaults = false
			return try context.fetch(request).first
		}

		static func newUniqueInstance(context: NSManagedObjectContext) throws -> ManagedCache {
			try find(context: context).map(context.delete)
			return ManagedCache(context: context)
		}
	}

	@objc(ManagedFeedImage)
	private class ManagedFeedImage: NSManagedObject {
		@NSManaged var id: UUID
		@NSManaged var imageDescription: String?
		@NSManaged var location: String?
		@NSManaged var url: URL
		@NSManaged var cache: ManagedCache?

		static func feedImage(_ feed: [LocalFeedImage], _ context: NSManagedObjectContext) -> NSOrderedSet {
			return NSOrderedSet(array: feed.map { feedItem in
				let managedFeed = ManagedFeedImage(context: context)
				managedFeed.id = feedItem.id
				managedFeed.imageDescription = feedItem.description
				managedFeed.location = feedItem.location
				managedFeed.url = feedItem.url
				return managedFeed
			})
		}

		var local: LocalFeedImage {
			LocalFeedImage(id: id, description: imageDescription, location: location, url: url)
		}
	}
}
