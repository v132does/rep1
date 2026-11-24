CREATE OR REPLACE FUNCTION IT.FUE_OBT_COD_ENT_PER(P_COD_PERSONA IN BA_PERSONAS.COD_PERSONA%TYPE)
 RETURN VARCHAR2 IS
  v_cod_ente ge_entes.cod_ente%type;
  v_cod_modulo ge_modalidades.cod_modulo%type;
  v_cod_modalidad ge_modalidades.cod_modalidad%type;
BEGIN
   Begin
       Select cl.cod_modulo, cl.cod_modalidad
         into v_cod_modulo, v_cod_modalidad
         from ge_cta_clientes cl
        where cl.cod_persona = P_COD_PERSONA
          and cl.relacion = 'P'
          and (exists (select 1 
                        from cc_cta_corrientes c
		                   where c.nro_cuenta = cl.nro_cuenta
		                     and c.estado in ('A','N')
                         and c.cod_ente is not null)
              or
		           exists (select 1 
                         from ah_cta_vistas e
		                    where e.nro_cuenta = cl.nro_cuenta
		                      and e.estado in ('A','N')
                          and e.cod_ente is not null))
          and rownum = 1;
   Exception
       when no_data_found then
          v_cod_modulo := null;
          v_cod_modalidad := null;
       when others then
          v_cod_modulo := null;
          v_cod_modalidad := null;
   End;
   if v_cod_modulo = 3 and v_cod_modalidad = 31 then
        Begin
            select a.cod_ente
              into v_cod_ente
              from ah_cta_vistas a,
                   ge_cta_clientes cl
              where cl.cod_persona = P_COD_PERSONA
              and cl.nro_cuenta = a.nro_cuenta
              and a.estado in ('A', 'N')
              and rownum =1
              and a.cod_ente is not null
              order by a.fec_apertura;
         Exception 
             when no_data_found then
                 v_cod_ente := null;
             when others then
                 v_cod_ente := null;
         End;
   elsif v_cod_modulo = 4 and v_cod_modalidad = 41 then
        Begin
            select c.cod_ente
              into v_cod_ente
              from cc_cta_corrientes c,
                   ge_cta_clientes cl
              where cl.cod_persona = P_COD_PERSONA
              and cl.nro_cuenta = c.nro_cuenta
              and c.estado in ('A', 'N')
              and c.cod_ente is not null
              and rownum =1
              order by c.fec_apertura;
         Exception 
             when no_data_found then
                 v_cod_ente := null;
             when others then
                 v_cod_ente := null;
         End;   
   else
       v_cod_ente := null;
   End if;
   return(v_cod_ente);
END;
/

