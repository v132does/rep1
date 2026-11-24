CREATE OR REPLACE FUNCTION IT.fug_obt_cta_renovada (p_nro_cuenta pr_cobros.nro_cuenta%type,
                              p_nro_cuota pr_cobros.nro_cuota%type,
                              p_fecha pr_cobros.fecha%type,
                              p_hora pr_cobros.hora%type) return varchar2 is
v_existe varchar2(1) := 'N';
v_nro_cta_renovada pr_cta_prestamos.nro_cta_renovada%type;
begin
   SELECT distinct 'S'
     INTO v_existe
     FROM gv_movimientos
    WHERE nro_cuenta = p_nro_cuenta
       AND fecha = p_fecha
       AND hora = p_hora
       AND nro_documento3 = p_nro_cuota
       AND cod_tra_padre = 359;
   IF v_existe = 'S' THEN
      SELECT nro_cta_renovada
        INTO v_nro_cta_renovada
        FROM pr_cta_prestamos p
       WHERE p.nro_cuenta = p_nro_cuenta;
   ELSE
      v_nro_cta_renovada := null;
   END IF;
   return v_nro_cta_renovada;
end;
/

