CREATE OR REPLACE FUNCTION IT.FUG_OBT_REF_ATRASO
 (P_PRO_ATRASO IN NUMBER, P_MAX_ATRASO IN NUMBER
 )
 RETURN VARCHAR2
 IS

v_cat_atraso varchar2(2);
BEGIN
      v_cat_atraso := null;
      if p_pro_atraso <= 5 then
         if p_max_atraso <= 5 then
            v_cat_atraso := 'EX';
         elsif p_max_atraso <= 15 then
            v_cat_atraso := 'MB';
         elsif p_max_atraso <= 30 then
            v_cat_atraso := 'BU';
         elsif p_max_atraso <= 45 then
            v_cat_atraso := 'RE';
         else
            v_cat_atraso := 'MA';
         end if;
      elsif p_pro_atraso <= 10 then
         if p_max_atraso <= 15 then
            v_cat_atraso := 'MB';
         elsif p_max_atraso <= 30 then
            v_cat_atraso := 'BU';
         elsif p_max_atraso <= 45 then
            v_cat_atraso := 'RE';
         else
            v_cat_atraso := 'MA';
         end if;
      elsif p_pro_atraso <= 20 then
         if p_max_atraso <= 30 then
            v_cat_atraso := 'BU';
         elsif p_max_atraso <= 45 then
            v_cat_atraso := 'RE';
         else
            v_cat_atraso := 'MA';
         end if;
      elsif p_pro_atraso <= 30 then
         if p_max_atraso <= 45 then
            v_cat_atraso := 'RE';
         else
            v_cat_atraso := 'MA';
         end if;
      else
         v_cat_atraso := 'MA';
      end if;   
  return v_cat_atraso;
END;
/

