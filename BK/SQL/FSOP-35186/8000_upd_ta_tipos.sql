DECLARE
  v_error                  varchar2(500);
  v_err                    varchar2(500);
  v_ermsj                  varchar2(500);
 
 cursor ta is
    select *
      from ta_tipos t
     where t.afinidad in ('114', '131', '138', '132', '139', '140', '174');
  begin 
   begin pre_ini_aplicacion; pae_cnf.g_cod_modulo := 1; end;
   --Desabilitar el trigger
    sql_util.ejecute_dml('alter trigger it.TB_TA_TIPOS disable', v_err);
    IF v_err IS NOT NULL THEN
      raise_application_error(-20000, 'Al desabilitar trigger de TA_TIPOS ' || v_err);
    END IF;
   
     for i in ta loop
       if i.afinidad = '114' then --VISA ORO 
         begin
            update it.ta_tipos t
            set t.descripcion = 'VISA ORO'
            where cod_modalidad = i.cod_modalidad
              and cod_modulo    = i.cod_modulo
              and nro_bin       = i.nro_bin
              and afinidad      = i.afinidad
              and sub_afinidad  = i.sub_afinidad;
           exception 
             when others then
             v_error := sqlcode;
             v_ermsj := sqlerrm;
             dbms_output.put_line(v_ermsj);
         end; 
       elsif i.afinidad in ('131', '138') then --VISA ORO EMPRESARIAL
         begin
            update it.ta_tipos t
            set t.descripcion = 'VISA ORO EMPRESARIAL'
            where cod_modalidad = i.cod_modalidad
              and cod_modulo    = i.cod_modulo
              and nro_bin       = i.nro_bin
              and afinidad      = i.afinidad
              and sub_afinidad  = i.sub_afinidad;
           exception 
             when others then
             v_error := sqlcode;
             v_ermsj := sqlerrm;
             dbms_output.put_line(v_ermsj);
         end;
       elsif i.afinidad = '132' then -- VISA SIGNATURE
         begin
            update it.ta_tipos t
            set t.descripcion = 'VISA SIGNATURE'
            where cod_modalidad = i.cod_modalidad
              and cod_modulo    = i.cod_modulo
              and nro_bin       = i.nro_bin
              and afinidad      = i.afinidad
              and sub_afinidad  = i.sub_afinidad;
           exception 
             when others then
             v_error := sqlcode;
             v_ermsj := sqlerrm;
             dbms_output.put_line(v_ermsj);
         end;
       elsif i.afinidad in ('139','140') then ----VISA ORO AGRO 
         begin
            update it.ta_tipos t
            set t.descripcion = 'VISA ORO AGRO'
            where cod_modalidad = i.cod_modalidad
              and cod_modulo    = i.cod_modulo
              and nro_bin       = i.nro_bin
              and afinidad      = i.afinidad
              and sub_afinidad  = i.sub_afinidad;
           exception 
             when others then
             v_error := sqlcode;
             v_ermsj := sqlerrm;
             dbms_output.put_line(v_ermsj);
         end;
         
       elsif i.afinidad = '174' then --MC BLACK 
         begin
            update it.ta_tipos t
            set t.descripcion = 'MC BLACK'
            where cod_modalidad = i.cod_modalidad
              and cod_modulo    = i.cod_modulo
              and nro_bin       = i.nro_bin
              and afinidad      = i.afinidad
              and sub_afinidad  = i.sub_afinidad;
           exception 
             when others then
             v_error := sqlcode;
             v_ermsj := sqlerrm;
             dbms_output.put_line(v_ermsj);
         end;
       
       end if;
      commit;
     end loop;
     --Habilitar trigger
      sql_util.ejecute_dml('alter trigger it.TB_TA_TIPOS enable', v_err);
    IF v_err IS NOT NULL THEN
      raise_application_error(-20000, 'Al Habilitar trigger de TA_TIPOS ' || v_err);
    END IF;
    
  end;
