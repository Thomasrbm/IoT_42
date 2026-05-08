.PHONY: up down clean fclean re

up:
	vagrant up

down:
	vagrant halt

clean:
	vagrant destroy -f
	rm -Rf shared .vagrant


fclean: clean
	rm -rf .vagrant/

re: fclean up