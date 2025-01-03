kube.get-all:
	@kubectl api-resources --verbs=list --namespaced -o name | while read resource; do \
		echo "================== $$resource ======================"; \
		kubectl get "$$resource" -n kube-system; \
		echo; \
	done