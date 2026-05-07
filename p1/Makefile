.PHONY: up down clean fclean re

up:
	vagrant up

down:
	vagrant halt

clean:
	vagrant destroy -f

fclean: clean
	rm -rf .vagrant/

re: fclean up