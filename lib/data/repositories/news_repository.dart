import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:sportyapp/data/models/stream_model.dart';

abstract class NewsRepository {
  Future<List<NewsItem>> getAllNews();
  Future<NewsItem?> getNewsById(String id);
  Future<void> addNews(NewsItem news);
  Future<List<NewsItem>> getLatestNews({int limit = 10});
}

class FirestoreNewsRepository implements NewsRepository {
  final FirebaseFirestore _firestore;

  FirestoreNewsRepository(this._firestore);

  @override
  Future<List<NewsItem>> getAllNews() async {
    try {
      final snapshot = await _firestore
          .collection('news')
          .orderBy('publishedAt', descending: true)
          .get();
      return snapshot.docs.map((doc) {
        final data = doc.data();
        return NewsItem(
          id: doc.id,
          headline: data['headline'] as String? ?? '',
          source: data['source'] as String? ?? '',
          thumbnailUrl: data['thumbnailUrl'] as String? ?? '',
          publishedAt: (data['publishedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
          category: data['category'] as String? ?? '',
          url: data['url'] as String? ?? '',
        );
      }).toList();
    } on FirebaseException {
      return [];
    }
  }

  @override
  Future<NewsItem?> getNewsById(String id) async {
    try {
      final doc = await _firestore.collection('news').doc(id).get();
      if (!doc.exists) return null;
      final data = doc.data()!;
      return NewsItem(
        id: doc.id,
        headline: data['headline'] as String? ?? '',
        source: data['source'] as String? ?? '',
        thumbnailUrl: data['thumbnailUrl'] as String? ?? '',
        publishedAt: (data['publishedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
        category: data['category'] as String? ?? '',
        url: data['url'] as String? ?? '',
      );
    } on FirebaseException {
      return null;
    }
  }

  @override
  Future<void> addNews(NewsItem news) async {
    try {
      await _firestore.collection('news').doc(news.id).set({
        'headline': news.headline,
        'source': news.source,
        'thumbnailUrl': news.thumbnailUrl,
        'publishedAt': Timestamp.fromDate(news.publishedAt),
        'category': news.category,
        'url': news.url,
      });
    } on FirebaseException {
      // silently fail
    }
  }

  @override
  Future<List<NewsItem>> getLatestNews({int limit = 10}) async {
    try {
      final snapshot = await _firestore
          .collection('news')
          .orderBy('publishedAt', descending: true)
          .limit(limit)
          .get();
      return snapshot.docs.map((doc) {
        final data = doc.data();
        return NewsItem(
          id: doc.id,
          headline: data['headline'] as String? ?? '',
          source: data['source'] as String? ?? '',
          thumbnailUrl: data['thumbnailUrl'] as String? ?? '',
          publishedAt: (data['publishedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
          category: data['category'] as String? ?? '',
          url: data['url'] as String? ?? '',
        );
      }).toList();
    } on FirebaseException {
      return [];
    }
  }
}
