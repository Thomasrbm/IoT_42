.PHONY: up down clean fclean re

up:
	vagrant up

down:
	vagrant halt

clean:
	vagrant destroy -f
	rm -rf .vagrant

fclean: clean

re: fclean up