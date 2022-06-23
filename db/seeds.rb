# This file should contain all the record creation needed to seed the database with its default values.
# The data can then be loaded with the bin/rails db:seed command (or created alongside the database with db:setup).
#
# Examples:
#
#   movies = Movie.create([{ name: "Star Wars" }, { name: "Lord of the Rings" }])
#   Character.create(name: "Luke", movie: movies.first)
post_1 = Post.create(description: "Test 1")
post_2 = Post.create(description: "Test 2")
post_3 = Post.create(description: "Test 3")

comment_1 = Comment.create(body: "Test 2", post: post_1)
comment_2 = Comment.create(body: "Test 2", post: post_1)
comment_3 = Comment.create(body: "Test 2", post: post_2)
comment_4 = Comment.create(body: "Test 2", post: post_2)

comment_5 = Comment.create(body: "Without post 1")
comment_6 = Comment.create(body: "Without post 2")