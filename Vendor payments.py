import pandas as pd
from scipy import stats
# 1.Finding whether Late payments are related to high  invoice amounts to pay using scipy stats
# It has ready-made functions for correlation and statistical tests,
# so you don’t calculate formulas by hand.


df= pd.read_csv(r"C:\Users\Tikshanna\OneDrive\Desktop\vendors_invoice.csv")
"""r,p_value =stats.pearsonr(df["amount_inr"],df["days_late"])
print("Correlation(r):",round(r,3))
print("p_value:",round(p_value,5))"""
# Invoice size vs days late: r=0.028, p=0.12 -> no real relationship,
# so size does NOT explain late payments (vendor and season do).

# 2.Next is the Q1 t-test,
# which checks whether Q1 payments are really later or whether it only looks that way by chance.


"""# Step 1: get the month number from due_date
df["due_month"]=pd.to_datetime(df["due_date"], format="%d-%m-%Y").dt.month

# Step 2: split into two groups
Q1 = df[df["due_month"].isin([1,2,3])]["days_late"]
rest= df[df["due_month"].isin([4,5,6,7,8,9,10,11,12])]["days_late"]

# Step 3: run the t-test
t_stat,p_value = stats.ttest_ind(Q1,rest,equal_var=False)
print("Q1 AVG late days:",round(Q1.mean(),1))
print("others AVG late days:",round(rest.mean(),1))
print("p_value:",p_value,5)"""

#checking whether the difference in vendors for late payment and whether vendor is the problem
"""# Step 1: average days late per vendor
print(df.groupby("vendor")["days_late"].mean().round(1).sort_values(ascending=False))
# Step 2: ANOVA across all 10 vendors

groups = [g["days_late"] for _, g in df.groupby("vendor")]
f_stat, p_value = stats.f_oneway(*groups)
print("F-statistic:", round(f_stat, 1))
print("p-value:", p_value)
"""
