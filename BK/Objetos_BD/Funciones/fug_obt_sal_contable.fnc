CREATE OR REPLACE FUNCTION IT.fug_obt_sal_contable(p_sal_tot IN ah_cta_certificados.sal_tot_batch%type,
                                                p_capital IN ah_cta_certificados.capital%type)
   RETURN NUMBER IS
BEGIN
   if p_sal_tot > p_capital then
    return(p_capital);
  else
    return(p_sal_tot);
  end if;
EXCEPTION
   WHEN no_data_found THEN
      RETURN(0);
END;
/

