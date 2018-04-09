
#ifndef _INDEX_SORT_H_
#define _INDEX_SORT_H_


class IndexComp
{
private:
    std::vector<double> const& m_v;

public:
    typedef bool result_type;

    IndexComp(std::vector<double> const& _v)
        : m_v(_v)
    {}

    bool operator()(std::size_t a, std::size_t b) const
    {
        return (m_v[a] > m_v[b]);
    }
};

#endif
