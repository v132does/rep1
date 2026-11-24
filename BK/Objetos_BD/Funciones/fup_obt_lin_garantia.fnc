CREATE OR REPLACE FUNCTION IT.FUP_OBT_LIN_GARANTIA
 (P_NRO_LINEA IN VARCHAR2
 )
 RETURN VARCHAR2
 IS

V_GARANTIAS VARCHAR2(1000);
v_cont number(3);
v_contador number(3) DEFAULT 0;
CURSOR garantia is
   select g.descripcion
     from pr_lineas t, pr_lin_tip_garantias l, pr_gar_tipos g
    where t.nro_linea = l.nro_linea
      and l.cod_garantia = g.cod_garantia
      and l.nro_linea = P_NRO_LINEA
 order by l.nro_linea, l.mto_limite desc, g.pri_aplicacion desc;
BEGIN
   select count(g.cod_garantia)
     into v_cont
     from pr_lineas t, pr_lin_tip_garantias l, pr_gar_tipos g
    where t.nro_linea = l.nro_linea
      and l.cod_garantia = g.cod_garantia
      and l.nro_linea = P_NRO_LINEA
    order by l.nro_linea, l.mto_limite desc, g.pri_aplicacion desc;
      
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

