CREATE OR REPLACE FUNCTION IT.FUG_OBT_CIR_PREAPROBADO(p_cod_modulo in number, p_cod_persona in ge_aut_solicitudes.cod_persona%type)
   RETURN VARCHAR2 IS
     v_existe varchar2(1) := 'N';
   BEGIN
     begin
       select 'S'
         into v_existe
         from ge_aut_solicitudes c
        where c.cod_modulo = p_cod_modulo
          and c.cod_persona = p_cod_persona
          and c.estado = 'A'
          and exists(select 1
                       from wf_circuitos t
                      where t.cod_tip_circuito = 30
                        and t.referencia = c.nro_pedido)
          and rownum = 1;
     exception
       when no_data_found then
          v_existe := 'N';
       when others then
          raise_application_error(-20000,'Error al buscar la referencia aprobada del circuito.'||sqlerrm);
     end;
     return nvl(v_existe,'N');
   END FUG_OBT_CIR_PREAPROBADO;
/

