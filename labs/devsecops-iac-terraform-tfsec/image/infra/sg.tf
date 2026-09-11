resource "aws_security_group" "web" {
  name        = "web-sg"
  description = "Security group do servidor web"

  # VULNERÁVEL: ingress na porta 22 (SSH) liberado pro mundo inteiro.
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}
