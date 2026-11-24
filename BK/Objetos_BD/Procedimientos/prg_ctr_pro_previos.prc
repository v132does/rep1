create or replace procedure it.prg_ctr_pro_previos(p_cod_proceso in NUMBER default null) is
  v_cod_pro_controlar ba_cod_referencias.val_minimo%type := NULL;
  v_des_proceso       ge_procesos.descripcion%type := NULL;
  v_cod_proceso       ge_procesos.cod_proceso%type := NULL;
begin

  -- proceso que controla que proceso previos configurados en BA_COD_REFERENCIAS tengan hora de finalización
  -- caso contrario interrumpe ejecucion y despliega un mensaje de error
  
  -- recupera desde BA_COD_REFERENCIAS procesos previos a controlar 
  begin
    select val_maximo
      into v_cod_pro_controlar
      from BA_COD_REFERENCIAS
     where dominio = 'COD_CTR_PRO_PREVIO'
       and val_minimo = p_cod_proceso;
  exception
    when others then
      v_cod_pro_controlar := null;
  end;
  if v_cod_pro_controlar is null then
    raise_application_error(-20000,
                            'No hay definidos procesos previos a controlar. cod_proceso: ' ||
                            p_cod_proceso);
  end if;

  -- consulta que recupera los procesos previos que no tengan hora de finalización
  begin
    select p.descripcion, p.cod_proceso
      into v_des_proceso, v_cod_proceso
      from ge_procesos p
     where p.cod_proceso IN
           (SELECT REGEXP_SUBSTR(v_cod_pro_controlar, '[^,]+', 1, LEVEL) AS data
              FROM dual
            CONNECT BY REGEXP_SUBSTR(v_cod_pro_controlar, '[^,]+', 1, LEVEL) IS NOT NULL)
       and p.hor_fin is null
       and rownum = 1;
  exception
    when others then
      v_des_proceso := null;
      v_cod_proceso := null;
  end;

  if v_des_proceso is not null or v_cod_proceso is not null then
    raise_application_error(-20000,
                            'Debe finalizar el proceso ' || v_cod_proceso || ' - ' ||
                            v_des_proceso ||
                            ' antes  poder ejecutar el proceso ' ||
                            p_cod_proceso);
  end if;

exception
  when others then
    raise_application_error(-20000,
                            'Error en proceso prg_ctr_pro_previos: ' ||
                            sqlerrm);
  
end prg_ctr_pro_previos;
/

