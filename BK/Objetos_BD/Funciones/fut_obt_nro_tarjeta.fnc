create or replace function it.fut_obt_nro_tarjeta(p_nro_cuenta in varchar2) return varchar2 is
  v_nro_tarjeta ta_tarjetas.nro_tarjeta%type;
--obtener el nro de tarjeta de crédito a partir del nro de cuenta
begin
  select b.nro_tarjeta
    into v_nro_tarjeta
    from ge_cta_clientes a, ta_tarjetas b
   where b.nro_cuenta = p_nro_cuenta
     and b.nro_cuenta = a.nro_cuenta
     and b.cod_persona = a.cod_persona
     and a.relacion = 'P'
     and b.vigente='S';
     return(v_nro_tarjeta);
exception
 when too_many_rows then
   select b.nro_tarjeta
    into v_nro_tarjeta
    from ge_cta_clientes a, ta_tarjetas b
   where b.nro_cuenta = p_nro_cuenta
     and b.nro_cuenta = a.nro_cuenta
     and b.cod_persona = a.cod_persona
     and a.relacion = 'P'
     and b.vigente='S'
     and rownum = 1;
     return(v_nro_tarjeta);
 when no_data_found then
     BEGIN
        SELECT t.nro_tarjeta
          INTO v_nro_tarjeta
          FROM ta_tarjetas t
         WHERE t.nro_cuenta = p_nro_cuenta
           AND vigente = 'S'
           AND rownum = 1;
           return(v_nro_tarjeta);
     EXCEPTION
        WHEN no_data_found THEN
           SELECT t.nro_tarjeta
             INTO v_nro_tarjeta
             FROM ta_tarjetas t
            WHERE t.nro_cuenta = p_nro_cuenta
              AND rownum = 1;
              return(v_nro_tarjeta);
        WHEN OTHERS THEN
           RETURN NULL;
     END;
 when OTHERS then
   RETURN NULL;
end fut_obt_nro_tarjeta;
/

