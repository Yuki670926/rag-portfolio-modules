output "collection_endpoint" {
  value = aws_opensearchserverless_collection.main.collection_endpoint
}

output "collection_arn" {
  value = aws_opensearchserverless_collection.main.arn
}

# OCU アラーム（cloudwatch モジュール）の次元用。GroupId は再作成のたびに変わるため
# Terraform グラフ経由で渡し、store flip 後もアラームが自動追従するようにする。
output "collection_group_id" {
  value = aws_opensearchserverless_collection_group.main.id
}

output "collection_group_name" {
  value = aws_opensearchserverless_collection_group.main.name
}
