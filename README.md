# README

This small project should help beginner developers to understand difference between Rails N+1 solving tools like `preload`, `includes`, `includes.references`, `joins` and  `eager_load` 

## Setup commands:
1. Clone the repo
2. Run `bundle` 
3. Run `bin/rake db:setup`

## Description
To describe all of the things above we need to create only parent `post` resource and children resource `comments` which are belongs to our `post`. See `schema.rb` if something is not clear for you.

## How should you detect N+1 problem?
Firstly, you need to understand it's a really common problem in projects where we have associations. I've made an example right here with N+1.
You can observe this issue simply running `bin/rails s` and navigate to http://127.0.0.1:3000/. In few words i'm trying to render
posts in `index.html.erb` (`@posts` here are `Post.all`) together with comments, but without preloading them. Here is logs from this request:
```ruby
Post Load (0.3ms)  SELECT "posts".* FROM "posts"
  ↳ app/views/posts/index.html.erb:1
  Comment Load (0.2ms)  SELECT "comments".* FROM "comments" WHERE "comments"."post_id" = $1  [["post_id", 7]]
  ↳ app/views/posts/index.html.erb:3
  Comment Load (0.1ms)  SELECT "comments".* FROM "comments" WHERE "comments"."post_id" = $1  [["post_id", 8]]
  ↳ app/views/posts/index.html.erb:3
  Comment Load (0.1ms)  SELECT "comments".* FROM "comments" WHERE "comments"."post_id" = $1  [["post_id", 9]]
  ↳ app/views/posts/index.html.erb:3
  Comment Load (0.1ms)  SELECT "comments".* FROM "comments" WHERE "comments"."post_id" = $1  [["post_id", 10]]
  ↳ app/views/posts/index.html.erb:3
  Comment Load (0.1ms)  SELECT "comments".* FROM "comments" WHERE "comments"."post_id" = $1  [["post_id", 11]]
  ↳ app/views/posts/index.html.erb:3
  Comment Load (0.1ms)  SELECT "comments".* FROM "comments" WHERE "comments"."post_id" = $1  [["post_id", 12]]
```
As you see for each post Rails generates a new SQL to fetch comments. Assume your production database has thousands of posts. It means a thousands of SQL queries will be executed. It will take a lot of time which is not good (user will wait a lot of time to load all of the stuff and also here is unnecessary database loading) 

You need also to understand this trick could be done via Rails console:
```ruby
irb(main):008:0> posts = Post.all
Post Load (0.4ms)  SELECT "posts".* FROM "posts"
=>
  [#<Post:0x00007fa7970a26c0                                                                     
    ...
irb(main):009:0> posts.first.comments.first
Comment Load (0.5ms)  SELECT "comments".* FROM "comments" WHERE "comments"."post_id" = $1 ORDER BY "comments"."id" ASC LIMIT $2  [["post_id", 7], ["LIMIT", 1]]
=>
  #<Comment:0x00007fa7970b4e38                             
  id: 9,
  body: "Test 2",
  created_at: Thu, 23 Jun 2022 13:01:40.347190000 UTC +00:00,
  updated_at: Thu, 23 Jun 2022 13:01:40.347190000 UTC +00:00,
  post_id: 7>
    irb(main):010:0> posts.first.comments.second
Comment Load (0.3ms)  SELECT "comments".* FROM "comments" WHERE "comments"."post_id" = $1 ORDER BY "comments"."id" ASC LIMIT $2 OFFSET $3  [["post_id", 7], ["LIMIT", 1], ["OFFSET", 1]]
=>
  #<Comment:0x00007fa797197418                                                                   
  id: 10,
  body: "Test 2",
  created_at: Thu, 23 Jun 2022 13:01:40.358340000 UTC +00:00,
  updated_at: Thu, 23 Jun 2022 13:01:40.358340000 UTC +00:00,
  post_id: 7> 
```
Here is an extra SQL query to fetch comments. Each time we call comments on post. Let's try it with preloading comments :)
```ruby
irb(main):011:0> posts = Post.preload(:comments)
Post Load (0.3ms)  SELECT "posts".* FROM "posts"
Comment Load (0.3ms)  SELECT "comments".* FROM "comments" WHERE "comments"."post_id" IN ($1, $2, $3, $4, $5, $6)  [["post_id", 7], ["post_id", 8], ["post_id", 9], ["post_id", 10], ["post_id", 11], ["post_id", 12]]
=>
  [#<Post:0x00007fa7972e5ce8                                                                     
    ...
irb(main):012:0> posts.first.comments.first
=>
  #<Comment:0x00007fa7972e98e8                                  
  id: 9,
  body: "Test 2",
  created_at: Thu, 23 Jun 2022 13:01:40.347190000 UTC +00:00,
  updated_at: Thu, 23 Jun 2022 13:01:40.347190000 UTC +00:00,
  post_id: 7>
irb(main):013:0> posts.first.comments.second
=>
  #<Comment:0x00007fa7972e9780                                  
  id: 10,
  body: "Test 2",
  created_at: Thu, 23 Jun 2022 13:01:40.358340000 UTC +00:00,
  updated_at: Thu, 23 Jun 2022 13:01:40.358340000 UTC +00:00,
  post_id: 7> 
```
As you see we preload comments once together with posts. And all of the future calling of comments didn't execute any SQL. I'll try to describe all of the preloading types below. 

## Preload
Lets see what preload will do in this project.
Preload loads the association data in a separate query.
```ruby
irb(main):009:0> Post.preload(:comments)
  Post Load (0.3ms)  SELECT "posts".* FROM "posts"
  Comment Load (0.3ms)  SELECT "comments".* FROM "comments" WHERE "comments"."post_id" IN ($1, $2, $3, $4, $5, $6)  [["post_id", 7], ["post_id", 8], ["post_id", 9], ["post_id", 10], ["post_id", 11], ["post_id", 12]]

```

Since `preload` always generates two sql we can't use `comments` table in `where` condition. Following query will result in an error.
```ruby
irb(main):013:0> Post.preload(:comments).where(comments: { body: "Test 2" }).to_a
  PG::UndefinedTable: ERROR:  missing FROM-clause entry for table "comments" (ActiveRecord::StatementInvalid) 
```
But you still able to use `posts` in `where` condition.

## Includes
Includes loads the association data in a separate query just like preload.

However it is smarter than preload. Above we saw that preload failed for query `Post.preload(:comments).where(comments: { body: "Test 2" })`. Let's try same with includes.
```ruby
irb(main):028:0> Post.includes(:comments).where(comments: { body: "Test 2" })
  SQL (0.5ms)  SELECT "posts"."id" AS t0_r0, "posts"."description" AS t0_r1, "posts"."created_at" AS t0_r2, 
  "posts"."updated_at" AS t0_r3, "comments"."id" AS t1_r0, "comments"."body" AS t1_r1, 
  "comments"."created_at" AS t1_r2, "comments"."updated_at" AS t1_r3, "comments"."post_id" AS t1_r4 
  FROM "posts" LEFT OUTER JOIN "comments" ON "comments"."post_id" = "posts"."id" WHERE "comments"."body" = $1  [["body", "Test 2"]]
```
As you can see includes switches from using two separate queries to creating a single `LEFT OUTER JOIN` to get the data. And it also applied the supplied condition.

So includes changes from two queries to a single query in some cases. By default for a simple case it will use two queries (the same as `preload`). Let's say that for some reason you want to force a simple includes case to use a single query instead of two. Use `references` to achieve that.
```ruby
Post.includes(:comments).references(:comments)
  SQL (0.4ms)  SELECT "posts"."id" AS t0_r0, "posts"."description" AS t0_r1, "posts"."created_at" AS t0_r2, 
  "posts"."updated_at" AS t0_r3, "comments"."id" AS t1_r0, "comments"."body" AS t1_r1, 
  "comments"."created_at" AS t1_r2, "comments"."updated_at" AS t1_r3, "comments"."post_id" AS t1_r4 
  FROM "posts" LEFT OUTER JOIN "comments" ON "comments"."post_id" = "posts"."id"     
```
In the above case a single query was done.

## Eager load
`eager_load` loads all association in a single query using LEFT OUTER JOIN.
```ruby
irb(main):032:0> Post.eager_load(:comments)
  SQL (0.5ms)  SELECT "posts"."id" AS t0_r0, "posts"."description" AS t0_r1, "posts"."created_at" AS t0_r2, 
  "posts"."updated_at" AS t0_r3, "comments"."id" AS t1_r0, "comments"."body" AS t1_r1, 
  "comments"."created_at" AS t1_r2, "comments"."updated_at" AS t1_r3, "comments"."post_id" AS t1_r4 
  FROM "posts" LEFT OUTER JOIN "comments" ON "comments"."post_id" = "posts"."id"
```
This is exactly what `includes` does when it is forced to make a single query when `where` or `order` clause is using an attribute from comments table.

## Joins
Joins brings association data using inner join.
```ruby
irb(main):033:0> Post.joins(:comments)
  Post Load (0.5ms)  SELECT "posts".* FROM "posts" INNER JOIN "comments" ON "comments"."post_id" = "posts"."id"
=>
  [#<Post:0x00007fa798cecd58                                                             
    id: 7,
    description: "Test 1",
    #<Post:0x00007fa798cecc90                                                             
    id: 7,
    description: "Test 1",
    #<Post:0x00007fa798cecbc8                                                             
    id: 8,
    description: "Test 2",
    #<Post:0x00007fa798cecb00
    id: 8,
    description: "Test 2",
    #<Post:0x00007fa798ceca38
    id: 10,
    description: "Test 1",
    #<Post:0x00007fa798cec970
    id: 10,
    description: "Test 1",
    #<Post:0x00007fa798cec8a8
    id: 11,
    description: "Test 2",
    #<Post:0x00007fa798cec7e0
    id: 11,
    description: "Test 2"
```
Above query produces duplicate result. We can avoid the duplication by using `distinct`.

Also if we want to use of attributes from comments table then we need to select them.
```ruby
irb(main):043:0> records = Post.joins(:comments).distinct.select("posts.*, comments.body as comments_body")
  Post Load (0.5ms)  SELECT DISTINCT posts.*, comments.body as comments_body FROM "posts" INNER JOIN "comments" ON "comments"."post_id" = "posts"."id"                                                                                        
=>                                                                                       
[#<Post:0x00007fa797d4f670                                                               
...                                                                                      
irb(main):044:0> records.map(&:comments_body)
=> ["Test 2", "Test 2", "Test 2", "Test 2"]
```
Note that using `joins` means if you use posts.comments then another query will be performed. I have to say personally i never used `joins` to fix N+1 issue. I use `joins`  when I need to fetch for example `posts` with `where` condition by any attribute of  comment, but don't need comments at all.

## Good topics to read 
https://tadhao.medium.com/joins-vs-preload-vs-includes-vs-eager-load-in-rails-5f721c44b3a9

Testing performance:
https://engineering.gusto.com/a-visual-guide-to-using-includes-in-rails/