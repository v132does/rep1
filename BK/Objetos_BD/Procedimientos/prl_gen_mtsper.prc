CREATE OR REPLACE PROCEDURE IT.PRL_GEN_MTSPER is

  v_directorio varchar2(20):= '/oradata/utl'; --DIR.SETEADA PARA PRODUCCION                                      
  v_archivo   utl_file.file_type;
  v_nom_ascii varchar2(26);
  v_buffer    varchar2(32767);

  cursor per is
    select Rpad(a.nro_referencia, 20, ' ') ||
           to_char(a.fec_operacion, 'YYYY-MM-DD') ||
           lpad(a.nro_ref_externa, 20, ' ') ||
           lpad(nvl(a.nro_cta_referencia, ' '), 20, ' ') ||
           lpad(nvl(a.cod_per_beneficiario, 0), 8, ' ') ||
           lpad(substr(a.nom_solicitante, 0, 60), 60, ' ') as l
      from lc_transferencias a, ge_calendarios b
     where b.cod_modulo = 7
       and a.cod_tip_referencia = 00
       and a.fec_operacion = b.fec_actual
    union all
    select Rpad(a.nro_operacion, 20, ' ') ||
           to_char(a.fec_operacion, 'YYYY-MM-DD') ||
           lpad(a.cod_tip_referencia || '/' || a.nro_referencia, 20, ' ') ||
           lpad(nvl(a.nro_cta_referencia, ' '), 20, ' ') ||
           lpad(a.cod_per_solicitante, 8, ' ') ||
           lpad(substr(fue_obt_nom_persona(a.cod_per_solicitante), 0, 60),
                60,
                ' ') as l
      from lc_transferencias a, ge_calendarios b
     where a.cod_per_solicitante is not null
       and b.cod_modulo = 7
       and a.fec_operacion = b.fec_actual;

begin
  if v_directorio is not null then
    begin
      FOR x in per loop
      
        v_buffer    := v_buffer || x.l || chr(10);
        v_nom_ascii := 'MTSPER' ||
                       to_char(fue_obt_fec_calendar(1), 'yyyymmdd') ||
                       '.txt';
        v_archivo   := utl_file.fopen(v_directorio, v_nom_ascii, 'A');
        utl_file.put_line(v_archivo, v_buffer);
        utl_file.fclose(v_archivo);
        v_buffer := '';
      END LOOP;
      if utl_file.is_open(v_archivo) then
        utl_file.fclose(v_archivo);
      end if;
    
    end;
  end if;
end prl_gen_mtsper;
/

