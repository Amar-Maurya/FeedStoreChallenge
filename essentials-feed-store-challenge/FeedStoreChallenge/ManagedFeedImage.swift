//
// Copyright © Essential Developer. All rights reserved.
//

import CoreData

@objc(ManagedFeedImage)
final class ManagedFeedImage: NSManagedObject {
	@NSManaged var id: UUID
	@NSManaged var imageDescription: String?
	@NSManaged var location: String?
	@NSManaged var url: URL
	@NSManaged var cache: ManagedCache?
}

extension ManagedFeedImage {
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
