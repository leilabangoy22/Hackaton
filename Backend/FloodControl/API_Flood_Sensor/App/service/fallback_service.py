class fallback_serviceClass:

    def fallback(new, old):
        return new if new not in (None, 0, "") else old