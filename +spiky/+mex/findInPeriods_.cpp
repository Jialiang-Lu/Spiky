#include "mex.hpp"
#include "mexAdapter.hpp"

using namespace matlab::data;
using namespace matlab::mex;

class MexFunction : public Function 
{
public:
    void operator()(ArgumentList outputs, ArgumentList inputs) 
    {
        checkArguments(inputs);
        const TypedArray<double> array = std::move(inputs[0]);
        const TypedArray<double> periods = std::move(inputs[1]);
        const bool rightClose = inputs.size() == 3 ? static_cast<bool>(std::move(inputs[2])[0]) : false;
        const size_t nPeriods = periods.getNumberOfElements() / 2;
        TypedArray<double> indices = factory.createArray<double>({nPeriods, 1});
        TypedArray<double> counts = factory.createArray<double>({nPeriods, 1});
        int n = array.getNumberOfElements();
        int index = 0;
        int next;
        for (int i = 0; i < nPeriods; i++)
        {
            double t0 = periods[i][0];
            double t1 = periods[i][1];
            for (; index < n && array[index] < t0; index++);
            indices[i] = static_cast<double>(index + 1);
            next = index;
            if (rightClose)
                for (; next < n && array[next] <= t1; next++);
            else
                for (; next < n && array[next] < t1; next++);
            counts[i] = static_cast<double>(next - index);
        }
        outputs[0] = std::move(indices);
        outputs[1] = std::move(counts);
    }

private:
    ArrayFactory factory;

    void checkArguments(ArgumentList inputs) 
    {
        if (inputs.size() < 2 || inputs.size() > 3)
        {
            getEngine()->feval(u"error",
                0, std::vector<Array>({ factory.createScalar("Wrong number of input arguments.") }));
        }
        if (inputs[0].getType() != ArrayType::DOUBLE || inputs[1].getType() != ArrayType::DOUBLE) 
        {
            getEngine()->feval(u"error",
                0, std::vector<Array>({ factory.createScalar("Input arguments must be of type double.") }));
        }
        if (inputs[1].getDimensions()[1] != 2)
        {
            getEngine()->feval(u"error",
                0, std::vector<Array>({ factory.createScalar("Periods must be a 2-column array.") }));
        }
        if (inputs.size() == 3 && inputs[2].getType() != ArrayType::LOGICAL)
        {
            getEngine()->feval(u"error",
                0, std::vector<Array>({ factory.createScalar("LeftClose must be of type logical.") }));
        }
    }
};