CREATE OR REPLACE FUNCTION IT.FUB_OBT_RUB_TRANSACCION
  (p_cod_modulo            IN NUMBER,
   p_cod_modalidad         IN NUMBER,
   p_cod_transaccion       IN NUMBER,
   p_cod_moneda            IN VARCHAR2,
   p_cod_persona           in varchar2,
   p_cod_plazo             IN VARCHAR2,
   p_tip_movimiento        IN VARCHAR2,
   p_est_cuenta            in varchar2 default null,
   p_tip_renovacion        in varchar2 default null,
   p_cat_automatica        in number default null,
   p_tip_interes           in varchar2 default null,
   p_tip_cuenta            in varchar2 default null,
   p_cod_sit_contable      ge_tip_asientos.cod_sit_contable%type default null,
   p_cod_sec_credito       pr_cta_prestamos.cod_sec_credito%type default null)
RETURN VARCHAR2 IS
v_cod_tip_asiento number(4);
v_cod_tip_asiento2 number(4);
v_ind_deudor varchar2(1);
v_ind_plazo varchar2(1);
v_ind_producto varchar2(1);
v_cod_pro_contable number(3);
v_cod_rubro  varchar2(20);
v_cod_sec_contable  VARCHAR2(01);
v_cod_tip_deudor    NUMBER(4);
v_residente         VARCHAR2(1);
v_cod_sec_rubro     pr_sec_creditos.cod_sec_rubro%type;
BEGIN
   /* busco el sector del cliente */
   Begin
   SELECT cod_sec_contable, cod_tip_deudor, residente
     into v_cod_sec_contable, v_cod_tip_deudor, v_residente
     from ge_clientes
    where cod_persona = p_cod_persona;
   Exception
      when others then
         v_cod_sec_contable := 'N';
         v_cod_tip_deudor   := 2;
         v_residente        := 'S';
   end;
   /* busco la transaccion que le corresponde */
   SELECT tr.cod_tip_asiento, cod_tip_asiento2, cod_pro_contable
     INTO v_cod_tip_asiento,  v_cod_tip_asiento2, v_cod_pro_contable
     FROM ge_modalidades mo, ge_transacciones tr
    WHERE tr.cod_modulo = p_cod_modulo
      AND tr.cod_modalidad = p_cod_modalidad
      AND tr.cod_transaccion = p_cod_transaccion
      and mo.cod_modulo = p_cod_modulo
      and mo.cod_modalidad = p_cod_modalidad;
   /* busco la cuenta contable que le corresponde */
   SELECT ind_plazo, ind_deudor, cod_rubro, ind_producto
     INTO v_ind_plazo,v_ind_deudor, v_cod_rubro, v_ind_producto
     FROM ge_tip_asientos
    WHERE cod_tip_asiento in (v_cod_tip_asiento, v_cod_tip_asiento2)
      AND cod_moneda = p_cod_moneda
      AND (cod_sec_contable is null or cod_sec_contable = v_cod_sec_contable)
      and (tip_renovacion is null or tip_renovacion = NVL(p_tip_renovacion,'A'))
      and (tip_interes is null or tip_interes = p_tip_interes)
      --and (tip_cuenta is null or tip_cuenta = p_tip_cuenta)
      and ((nvl(p_tip_cuenta, 'x') = 'B' and tip_cuenta = p_tip_cuenta) or
           (nvl(p_tip_cuenta, 'x') <> 'B' and (tip_cuenta is null or tip_cuenta = p_tip_cuenta)))
      and (cat_automatica is null or cat_automatica = p_cat_automatica)
      and (est_cuenta is null or est_cuenta = p_est_cuenta)
      AND (ind_residente = 'X' OR ind_residente = v_residente)
      AND tip_movimiento = p_tip_movimiento
      and (cod_sit_contable is null or cod_sit_contable = p_cod_sit_contable)
      AND nro_linea =  ( Select min(nro_linea)
                           FROM ge_tip_asientos
                          WHERE cod_tip_asiento in (v_cod_tip_asiento, v_cod_tip_asiento2)
                            AND cod_moneda = p_cod_moneda
                            AND (cod_sec_contable is null or cod_sec_contable = v_cod_sec_contable)
                            and (tip_renovacion is null or tip_renovacion = NVL(p_tip_renovacion,'A'))
                            and (tip_interes is null or tip_interes = p_tip_interes)
                            --and (tip_cuenta is null or tip_cuenta = p_tip_cuenta)
                            and ((nvl(p_tip_cuenta, 'x') = 'B' and tip_cuenta = p_tip_cuenta) or
                                 (nvl(p_tip_cuenta, 'x') <> 'B' and (tip_cuenta is null or tip_cuenta = p_tip_cuenta)))
                            and (cat_automatica is null or cat_automatica = p_cat_automatica)
                            and (est_cuenta is null or est_cuenta = p_est_cuenta)
                            AND (ind_residente = 'X' OR ind_residente = v_residente)
                            and (cod_sit_contable is null or cod_sit_contable = p_cod_sit_contable)
                            AND tip_movimiento = p_tip_movimiento);
   IF v_ind_plazo = 'S' then
      v_cod_rubro := substr(v_cod_rubro,1,2)||p_cod_plazo||
                    substr(v_cod_rubro,4,12);
   END IF;
   IF v_ind_deudor = 'S' OR substr(v_cod_rubro,9,2) = 'TD' then
      v_cod_rubro := substr(v_cod_rubro,1,8)||
                    (ltrim(to_char(v_cod_tip_deudor,'00')))||
                    substr(v_cod_rubro,11,5);
   END IF;
   ---Reemplaza el codigo del producto -----------------------
   IF v_IND_PRODUCTO = 'S' THEN
      v_cod_rubro := SUBSTR(v_cod_rubro,1,10)||
                     LTRIM(TO_CHAR(v_cod_pro_contable,'000'))||
                     SUBSTR(v_cod_rubro,14,2);
   END IF;
   IF substr(v_cod_rubro,11,3)  = 'SEC' THEN
      -- es solo para prestamos, para contabilizar por sector
      v_cod_rubro := SUBSTR(v_cod_rubro,1,10)||
                    LTRIM(TO_CHAR(FUP_OBT_SEC_RUBRO(p_cod_sec_credito),'000'))||
                    SUBSTR(v_cod_rubro,14,2);
   END IF;
   return v_cod_rubro;
EXCEPTION
   WHEN OTHERS THEN
        v_cod_rubro := NULL;
        return v_cod_rubro;
END;
--- fin del obtener codigo de rubro------------------------------------
/

