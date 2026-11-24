CREATE OR REPLACE FUNCTION IT.FUP_OBT_PRE_GARANTIA
 (P_NRO_CUENTA IN PR_CTA_PRESTAMOS.NRO_CUENTA%TYPE
 )
 RETURN VARCHAR2
 IS

V_GARANTIAS VARCHAR2(1000);
V_CONTADOR VARCHAR2(240) := '0';
V_CONT VARCHAR2(240) := '0';
CURSOR garantia is
   select g.descripcion
     from pr_cta_garantias t, pr_gar_tipos g
    where t.cod_garantia = g.cod_garantia
    and t.nro_cuenta = P_NRO_CUENTA
 order by t.nro_cuenta, g.pri_aplicacion desc;
BEGIN
   select count(g.cod_garantia)
     into v_cont
     from pr_cta_garantias t, pr_gar_tipos g
    where t.cod_garantia = g.cod_garantia
    and t.nro_cuenta = P_NRO_CUENTA
 order by t.nro_cuenta, g.pri_aplicacion desc;

     FOR reg in garantia loop
        v_contador := v_contador + 1;
        if v_contador = 1 then
           V_GARANTIAS := reg.descripcion;
        elsif v_cont > 1 and  v_contador < v_cont then
           V_GARANTIAS := V_GARANTIAS||', '||reg.descripcion;
        elsif v_contador = v_cont then
           V_GARANTIAS := V_GARANTIAS||' y '||reg.descripcion;
           V_GARANTIAS := replace (V_GARANTIAS,' y HI',' e HI') ;
           V_GARANTIAS := replace (V_GARANTIAS,' y HI',' e I');
        end if;
      END LOOP;
      RETURN V_GARANTIAS;
END;
/

