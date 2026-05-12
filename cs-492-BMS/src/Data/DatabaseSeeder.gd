extends Node

# ══════════════════════════════════════════════════════════════════════════════
#  DatabaseSeeder.gd
#
#  Populates the BookStore database with realistic dummy data:
#    • 40 books across 8 genres
#    • 20 customers
#    • ~120 sales spread across the last 12 months
#
#  HOW TO USE:
#    1. Add this script as a scene (e.g. Seeder.tscn) with a single Node root.
#    2. Run the scene once — it seeds the DB and prints a summary.
#    3. Remove or disable the scene afterwards (data persists in the .db file).
#
#  SAFE TO RE-RUN: Checks for existing data first and bails out early so you
#  won't end up with duplicates.
# ══════════════════════════════════════════════════════════════════════════════

# ── Data tables ───────────────────────────────────────────────────────────────

const BOOKS := [
	# Fiction
	{ "title": "The Midnight Library",        "author": "Matt Haig",             "isbn": "9780525559474", "genre": "Fiction",      "publisher": "Viking",          "year": 2020, "price": 16.99, "cost": 7.50,  "stock": 42, "description": "A library between life and death where every book is a different life you could have lived." },
	{ "title": "Klara and the Sun",            "author": "Kazuo Ishiguro",        "isbn": "9780593311295", "genre": "Fiction",      "publisher": "Knopf",           "year": 2021, "price": 17.95, "cost": 8.00,  "stock": 35, "description": "An Artificial Friend observes the world and the humans she serves." },
	{ "title": "The Vanishing Half",           "author": "Brit Bennett",          "isbn": "9780525536291", "genre": "Fiction",      "publisher": "Riverhead",       "year": 2020, "price": 15.99, "cost": 6.80,  "stock": 28, "description": "Twin sisters live divergent lives as one passes for white and one stays in their Black community." },
	{ "title": "Cloud Cuckoo Land",            "author": "Anthony Doerr",         "isbn": "9781982168438", "genre": "Fiction",      "publisher": "Scribner",        "year": 2021, "price": 19.99, "cost": 9.00,  "stock": 20, "description": "Five characters across centuries are linked by an ancient text." },
	{ "title": "Demon Copperhead",             "author": "Barbara Kingsolver",    "isbn": "9780063251922", "genre": "Fiction",      "publisher": "Harper",          "year": 2022, "price": 18.99, "cost": 8.50,  "stock": 31, "description": "A Pulitzer Prize-winning retelling of David Copperfield set in Appalachia." },
	# Mystery / Thriller
	{ "title": "The Thursday Murder Club",     "author": "Richard Osman",         "isbn": "9781984880963", "genre": "Mystery",      "publisher": "Pamela Dorman",   "year": 2020, "price": 14.99, "cost": 6.00,  "stock": 50, "description": "Four retirees meet weekly to investigate cold cases — until a real murder lands on their doorstep." },
	{ "title": "The Maid",                     "author": "Nita Prose",            "isbn": "9780593314425", "genre": "Mystery",      "publisher": "Ballantine",      "year": 2022, "price": 13.99, "cost": 5.50,  "stock": 44, "description": "Hotel maid Molly Gray discovers a dead body and becomes the prime suspect." },
	{ "title": "Killers of a Certain Age",     "author": "Deanna Raybourn",       "isbn": "9780593098417", "genre": "Mystery",      "publisher": "Berkley",         "year": 2022, "price": 16.00, "cost": 7.00,  "stock": 22, "description": "Four retired female assassins are targeted by the very organization they served." },
	{ "title": "The Wager",                    "author": "David Grann",           "isbn": "9780385534260", "genre": "Mystery",      "publisher": "Doubleday",       "year": 2023, "price": 17.99, "cost": 8.20,  "stock": 18, "description": "A shipwreck, a mutiny, and a sensational trial in the 18th century." },
	{ "title": "Suspect",                      "author": "Scott Turow",           "isbn": "9781538742785", "genre": "Mystery",      "publisher": "Grand Central",   "year": 2022, "price": 15.00, "cost": 6.50,  "stock": 15, "description": "A defense attorney uncovers uncomfortable truths about a police chief accused of rape." },
	# Science Fiction
	{ "title": "Project Hail Mary",            "author": "Andy Weir",             "isbn": "9780593135204", "genre": "Sci-Fi",       "publisher": "Ballantine",      "year": 2021, "price": 18.00, "cost": 8.00,  "stock": 60, "description": "A lone astronaut wakes with no memory and must save the Earth." },
	{ "title": "A Memory Called Empire",       "author": "Arkady Martine",        "isbn": "9781250186430", "genre": "Sci-Fi",       "publisher": "Tor",             "year": 2019, "price": 16.99, "cost": 7.20,  "stock": 25, "description": "An ambassador investigates a disappearance in a vast interstellar empire." },
	{ "title": "The Galaxy and the Ground Within","author": "Becky Chambers",     "isbn": "9780062936042", "genre": "Sci-Fi",       "publisher": "Harper Voyager",  "year": 2021, "price": 15.99, "cost": 6.80,  "stock": 33, "description": "Stranded travellers find community and connection at a waystation." },
	{ "title": "Starter Villain",              "author": "John Scalzi",           "isbn": "9780765389220", "genre": "Sci-Fi",       "publisher": "Tor",             "year": 2023, "price": 17.99, "cost": 8.00,  "stock": 27, "description": "A man inherits his uncle's supervillain business — along with its complications." },
	{ "title": "Light from Uncommon Stars",    "author": "Ryka Aoki",             "isbn": "9781250789068", "genre": "Sci-Fi",       "publisher": "Tor",             "year": 2021, "price": 16.00, "cost": 7.00,  "stock": 19, "description": "A violin teacher who sold souls to the devil meets an alien refugee running a donut shop." },
	# Fantasy
	{ "title": "The House in the Cerulean Sea","author": "TJ Klune",              "isbn": "9781250217318", "genre": "Fantasy",      "publisher": "Tor",             "year": 2020, "price": 15.99, "cost": 6.50,  "stock": 55, "description": "A caseworker is sent to inspect a magical orphanage and ends up falling in love." },
	{ "title": "The Name of the Wind",         "author": "Patrick Rothfuss",      "isbn": "9780756404741", "genre": "Fantasy",      "publisher": "DAW",             "year": 2007, "price": 14.99, "cost": 5.80,  "stock": 40, "description": "The legendary story of Kvothe, told in his own voice." },
	{ "title": "A Court of Thorns and Roses",  "author": "Sarah J. Maas",         "isbn": "9781619634459", "genre": "Fantasy",      "publisher": "Bloomsbury",      "year": 2015, "price": 13.99, "cost": 5.20,  "stock": 70, "description": "A huntress is taken to a magical land after killing a wolf in the woods." },
	{ "title": "Piranesi",                     "author": "Susanna Clarke",        "isbn": "9781635575644", "genre": "Fantasy",      "publisher": "Bloomsbury",      "year": 2020, "price": 14.00, "cost": 5.90,  "stock": 30, "description": "A man lives alone in a labyrinthine House filled with infinite halls and statues." },
	{ "title": "Babel",                        "author": "R.F. Kuang",            "isbn": "9780063021426", "genre": "Fantasy",      "publisher": "Harper Voyager",  "year": 2022, "price": 19.99, "cost": 9.50,  "stock": 24, "description": "Oxford's Royal Institute of Translation holds the key to the British Empire's power." },
	# Non-Fiction
	{ "title": "Educated",                     "author": "Tara Westover",         "isbn": "9780399590504", "genre": "Non-Fiction",  "publisher": "Random House",    "year": 2018, "price": 15.00, "cost": 5.80,  "stock": 38, "description": "A memoir about a woman who grows up in a survivalist family and educates herself." },
	{ "title": "Sapiens",                      "author": "Yuval Noah Harari",     "isbn": "9780062316097", "genre": "Non-Fiction",  "publisher": "Harper",          "year": 2015, "price": 18.00, "cost": 7.50,  "stock": 45, "description": "A brief history of humankind from the Stone Age to the present." },
	{ "title": "The Body Keeps the Score",     "author": "Bessel van der Kolk",   "isbn": "9780143127741", "genre": "Non-Fiction",  "publisher": "Penguin",         "year": 2014, "price": 17.00, "cost": 7.00,  "stock": 29, "description": "How trauma reshapes body and mind, and paths to recovery." },
	{ "title": "Atomic Habits",                "author": "James Clear",           "isbn": "9780735211292", "genre": "Non-Fiction",  "publisher": "Avery",           "year": 2018, "price": 16.99, "cost": 6.80,  "stock": 66, "description": "A proven framework for building good habits and breaking bad ones." },
	{ "title": "Say Nothing",                  "author": "Patrick Radden Keefe",  "isbn": "9780307279279", "genre": "Non-Fiction",  "publisher": "Doubleday",       "year": 2019, "price": 16.00, "cost": 6.50,  "stock": 21, "description": "A murder in Northern Ireland illuminates the Troubles and their aftermath." },
	# Biography
	{ "title": "The Storyteller",              "author": "Dave Grohl",            "isbn": "9780063076099", "genre": "Biography",    "publisher": "Dey Street",      "year": 2021, "price": 17.99, "cost": 8.00,  "stock": 32, "description": "Tales of life and music from the Nirvana drummer and Foo Fighters founder." },
	{ "title": "Open",                         "author": "Andre Agassi",          "isbn": "9780307388407", "genre": "Biography",    "publisher": "Knopf",           "year": 2009, "price": 14.99, "cost": 5.80,  "stock": 18, "description": "An honest and revealing autobiography from one of tennis's greatest players." },
	{ "title": "I Am Malala",                  "author": "Malala Yousafzai",      "isbn": "9780316322409", "genre": "Biography",    "publisher": "Little Brown",    "year": 2013, "price": 13.99, "cost": 5.20,  "stock": 26, "description": "The story of the girl who stood up for education and was shot by the Taliban." },
	{ "title": "Born a Crime",                 "author": "Trevor Noah",           "isbn": "9780399588174", "genre": "Biography",    "publisher": "Spiegel & Grau",  "year": 2016, "price": 14.99, "cost": 5.80,  "stock": 48, "description": "Trevor Noah's memoir growing up in apartheid South Africa." },
	{ "title": "Greenlights",                  "author": "Matthew McConaughey",   "isbn": "9780593139134", "genre": "Biography",    "publisher": "Crown",           "year": 2020, "price": 16.00, "cost": 7.00,  "stock": 22, "description": "Raucous stories and wisdom from the Oscar-winning actor's journal entries." },
	# Children
	{ "title": "The One and Only Ivan",        "author": "Katherine Applegate",   "isbn": "9780061992254", "genre": "Children",     "publisher": "Harper",          "year": 2012, "price": 9.99,  "cost": 3.80,  "stock": 35, "description": "A gorilla living in a mall discovers art and friendship in this Newbery winner." },
	{ "title": "Wonder",                       "author": "R.J. Palacio",          "isbn": "9780375869020", "genre": "Children",     "publisher": "Knopf",           "year": 2012, "price": 10.99, "cost": 4.20,  "stock": 52, "description": "A boy with facial differences navigates his first year in mainstream school." },
	{ "title": "Hilo: The Boy Who Crashed to Earth","author": "Judd Winick",      "isbn": "9780385386173", "genre": "Children",     "publisher": "Random House",    "year": 2015, "price": 9.00,  "cost": 3.50,  "stock": 40, "description": "A robot boy falls from the sky and befriends two kids in this graphic novel series." },
	{ "title": "Dog Man",                      "author": "Dav Pilkey",            "isbn": "9780545581608", "genre": "Children",     "publisher": "Scholastic",      "year": 2016, "price": 9.99,  "cost": 3.90,  "stock": 65, "description": "The world's most epic hero — half dog, half man — in a hilarious graphic novel." },
	{ "title": "Wings of Fire: The Dragonet Prophecy","author": "Tui T. Sutherland","isbn": "9780545349185","genre": "Children",   "publisher": "Scholastic",      "year": 2012, "price": 8.99,  "cost": 3.40,  "stock": 58, "description": "Five dragonets destined to end a war struggle to fulfil their prophecy." },
	# History
	{ "title": "The Splendid and the Vile",    "author": "Erik Larson",           "isbn": "9780385348713", "genre": "History",      "publisher": "Crown",           "year": 2020, "price": 17.99, "cost": 7.80,  "stock": 23, "description": "Churchill and his family endure the London Blitz during World War II." },
	{ "title": "Killers of the Flower Moon",   "author": "David Grann",           "isbn": "9780307742483", "genre": "History",      "publisher": "Doubleday",       "year": 2017, "price": 16.99, "cost": 7.00,  "stock": 37, "description": "The Osage murders and the birth of the FBI." },
	{ "title": "The Warmth of Other Suns",     "author": "Isabel Wilkerson",      "isbn": "9780679763888", "genre": "History",      "publisher": "Random House",    "year": 2010, "price": 18.00, "cost": 7.50,  "stock": 19, "description": "The epic story of America's Great Migration through three individuals' journeys." },
	{ "title": "1776",                         "author": "David McCullough",       "isbn": "9780743226721", "genre": "History",      "publisher": "Simon & Schuster","year": 2005, "price": 15.99, "cost": 6.20,  "stock": 16, "description": "The story of America's founding year, told through Washington's struggles." },
	{ "title": "SPQR",                         "author": "Mary Beard",            "isbn": "9781631492228", "genre": "History",      "publisher": "Liveright",       "year": 2015, "price": 16.00, "cost": 6.80,  "stock": 14, "description": "A history of ancient Rome that asks why it still matters today." },
]

const CUSTOMERS := [
	{ "name": "Alice Thornton",    "email": "alice.thornton@email.com",  "phone": "555-0101", "notes": "Prefers literary fiction. Newsletter subscriber." },
	{ "name": "Ben Okafor",        "email": "ben.okafor@webmail.net",    "phone": "555-0102", "notes": "Big sci-fi fan. Asks about new releases every visit." },
	{ "name": "Carmen Reyes",      "email": "c.reyes@mailbox.org",       "phone": "555-0103", "notes": "Buys children's books in bulk — probably a teacher." },
	{ "name": "David Liang",       "email": "david.liang@fastnet.com",   "phone": "555-0104", "notes": "History and biography only. Very discerning taste." },
	{ "name": "Evelyn Marsh",      "email": "emarsh@quickpost.io",       "phone": "555-0105", "notes": "Fantasy enthusiast. Attends our book club." },
	{ "name": "Frank Ortega",      "email": "fortega@homemail.com",      "phone": "555-0106", "notes": "Thriller reader. Cash payer." },
	{ "name": "Grace Nguyen",      "email": "grace.nguyen@email.com",    "phone": "555-0107", "notes": "Non-fiction and self-help. Works nearby." },
	{ "name": "Henry Brandt",      "email": "hbrandt@webmail.net",       "phone": "555-0108", "notes": "Occasional buyer. Always uses gift cards." },
	{ "name": "Isla Mackenzie",    "email": "imackenzie@mailbox.org",    "phone": "555-0109", "notes": "Romance and fantasy crossover fan." },
	{ "name": "James Delacroix",   "email": "j.delacroix@fastnet.com",   "phone": "555-0110", "notes": "Professor — orders multiple copies of the same title." },
	{ "name": "Kayla Torres",      "email": "kayla.t@quickpost.io",      "phone": "555-0111", "notes": "Young adult and children's section regular." },
	{ "name": "Leo Fischer",       "email": "leo.fischer@homemail.com",  "phone": "555-0112", "notes": "Mystery lover. Volunteers at the library." },
	{ "name": "Mia Johansson",     "email": "mia.j@email.com",           "phone": "555-0113", "notes": "Prefers hardcovers. Spends big when she visits." },
	{ "name": "Nathan Cross",      "email": "ncross@webmail.net",        "phone": "555-0114", "notes": "Science and non-fiction. Referred by David Liang." },
	{ "name": "Olivia Shaw",       "email": "oshaw@mailbox.org",         "phone": "555-0115", "notes": "Huge Agassi and celebrity memoir fan." },
	{ "name": "Paul Kimura",       "email": "pkimura@fastnet.com",       "phone": "555-0116", "notes": "Graphic novels and illustrated books." },
	{ "name": "Quinn Patel",       "email": "qpatel@quickpost.io",       "phone": "555-0117", "notes": "Book club organiser. Monthly regular." },
	{ "name": "Rachel Bloom",      "email": "r.bloom@homemail.com",      "phone": "555-0118", "notes": "Prefers e-receipts. Always pays by card." },
	{ "name": "Sam Delgado",       "email": "sdelgado@email.com",        "phone": "555-0119", "notes": "Walk-in customer. No consistent preference." },
	{ "name": "Tina Volkov",       "email": "tvolkov@webmail.net",       "phone": "555-0120", "notes": "Eastern European lit and translated fiction." },
]

# Weights control how often each book appears in sales (higher = more popular)
const BOOK_POPULARITY := [
	3, 2, 2, 1, 2,   # Fiction
	4, 3, 2, 2, 1,   # Mystery
	5, 2, 2, 3, 1,   # Sci-Fi
	4, 3, 5, 2, 2,   # Fantasy
	3, 4, 3, 5, 2,   # Non-Fiction
	2, 1, 2, 3, 2,   # Biography
	3, 4, 2, 5, 4,   # Children
	2, 3, 1, 1, 1,   # History
]

const PAYMENT_METHODS := ["cash", "card", "card", "card", "gift_card"]

# ── Entry point ───────────────────────────────────────────────────────────────

func _ready() -> void:
	# Give the BookStore autoload a frame to open the DB
	await get_tree().process_frame

	if _already_seeded():
		print("[Seeder] Database already contains data — skipping.")
		return

	print("[Seeder] Starting seed...")
	var rng := RandomNumberGenerator.new()
	rng.randomize()

	var book_ids    := _seed_books(rng)
	var customer_ids := _seed_customers()
	_seed_sales(rng, book_ids, customer_ids)

	var metrics := BookStore.get_dashboard_metrics()
	print("[Seeder] ── Done ─────────────────────────────────")
	print("[Seeder]  Titles in DB : ", metrics["titles"])
	print("[Seeder]  Inventory    : ", metrics["inventory"])
	print("[Seeder]  Customers    : ", metrics["customers"])
	print("[Seeder]  Monthly rev  : $", snappedf(metrics["revenue"], 0.01))
	print("[Seeder] ─────────────────────────────────────────")


# ── Guard ─────────────────────────────────────────────────────────────────────

func _already_seeded() -> bool:
	var books := BookStore.get_all_books()
	return books.size() > 0


# ── Books ─────────────────────────────────────────────────────────────────────

func _seed_books(rng: RandomNumberGenerator) -> Array:
	var ids := []
	for book in BOOKS:
		# Add a bit of price variance so the data isn't totally uniform
		var data = book.duplicate()
		data["low_stock_alert"] = 5 + rng.randi_range(0, 5)
		var id := BookStore.add_book(data)
		ids.append(id)
	print("[Seeder] Inserted %d books." % ids.size())
	return ids


# ── Customers ─────────────────────────────────────────────────────────────────

func _seed_customers() -> Array:
	var ids := []
	for cust in CUSTOMERS:
		var id := BookStore.add_customer(cust)
		ids.append(id)
	print("[Seeder] Inserted %d customers." % ids.size())
	return ids


# ── Sales ─────────────────────────────────────────────────────────────────────
#
#  Generates ~120 sales spread over the last 12 months.
#  Each sale has 1–4 line items chosen via a weighted random draw.
#  After inserting, we back-date created_at using a raw UPDATE so the
#  dashboard's monthly revenue charts look interesting.

func _seed_sales(rng: RandomNumberGenerator, book_ids: Array, customer_ids: Array) -> void:
	var total_sales := 0
	# Build a flat weighted list of book indices for easy sampling
	var weighted_pool := _build_weighted_pool()

	for month_offset in range(12, -1, -1):
		# More sales in recent months; fewer in older ones
		var sales_this_month := rng.randi_range(6, 14) + (12 - month_offset) / 3

		for _s in range(sales_this_month):
			# Pick 1-4 distinct books
			var num_items := rng.randi_range(1, 4)
			var picked_indices := _pick_unique(rng, weighted_pool, num_items)

			var cart := []
			for idx in picked_indices:
				var book_id: int = book_ids[idx]
				var book_data: Dictionary = BookStore.get_book(book_id)
				if book_data.is_empty():
					continue
				var qty := rng.randi_range(1, 3)
				cart.append({
					"book_id": book_id,
					"qty":     qty,
					"price":   book_data["price"],
				})

			if cart.is_empty():
				continue

			# Occasionally make it a walk-in (no customer)
			var cust_id := -1
			if rng.randf() > 0.25:
				cust_id = customer_ids[rng.randi_range(0, customer_ids.size() - 1)]

			var payment = PAYMENT_METHODS[rng.randi_range(0, PAYMENT_METHODS.size() - 1)]
			var sale_id := BookStore.complete_sale(cart, payment, cust_id)

			# Back-date the sale to a random day within the target month
			var fake_date := _random_date_in_month(rng, month_offset)
			BookStore.db.query_with_bindings(
				"UPDATE sales SET created_at = ? WHERE id = ?;",
				[fake_date, sale_id]
			)
			total_sales += 1

	print("[Seeder] Inserted %d sales." % total_sales)


# ── Helpers ───────────────────────────────────────────────────────────────────

func _build_weighted_pool() -> Array:
	var pool := []
	for i in range(BOOK_POPULARITY.size()):
		for _w in range(BOOK_POPULARITY[i]):
			pool.append(i)
	return pool


func _pick_unique(rng: RandomNumberGenerator, pool: Array, count: int) -> Array:
	var seen := {}
	var result := []
	var max_attempts := count * 10
	var attempts := 0
	while result.size() < count and attempts < max_attempts:
		var pick: int = pool[rng.randi_range(0, pool.size() - 1)]
		if not seen.has(pick):
			seen[pick] = true
			result.append(pick)
		attempts += 1
	return result


func _random_date_in_month(rng: RandomNumberGenerator, months_ago: int) -> String:
	var now   := Time.get_date_dict_from_system()
	var year  : int = now["year"]
	var month : int = now["month"] - months_ago

	while month < 1:
		month += 12
		year  -= 1

	# Days in month (rough — SQLite won't care about Feb edge cases in dummy data)
	var days_in_month := 28
	match month:
		1, 3, 5, 7, 8, 10, 12: days_in_month = 31
		4, 6, 9, 11:            days_in_month = 30

	var day  := rng.randi_range(1, days_in_month)
	var hour := rng.randi_range(9, 20)
	var min_ := rng.randi_range(0, 59)

	return "%04d-%02d-%02d %02d:%02d:00" % [year, month, day, hour, min_]
