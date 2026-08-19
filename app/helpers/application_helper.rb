module ApplicationHelper
  def qty(n)
    n.zero? ? "-" : n.to_s
  end
end
