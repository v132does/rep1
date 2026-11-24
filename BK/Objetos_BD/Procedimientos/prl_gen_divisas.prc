CREATE OR REPLACE PROCEDURE IT.PRL_GEN_DIVISAS is

  v_directorio varchar2(20) := fug_obt_pardinamico('DIR_REP_FTP'); --DIR.SETEADA PARA PRODUCCION                                      
  v_archivo    utl_file.file_type;
  v_nom_ascii  varchar2(26);
  v_buffer     varchar2(32767);
  cursor per is
    select a.cod_moneda || lpad(trunc(a.val_conversion), 4, 0) ||
           lpad(nvl(substr(a.val_conversion - trunc(a.val_conversion), 2, 5),
                    0),
                5,
                0) || to_char(a.fecha, 'YYYY-MM-DD') as l
      from ge_cotizaciones a, ge_calendarios b
     where a.fecha = b.fec_actual
       and b.cod_modulo = 7;

begin
  if v_directorio is not null then
    begin
      FOR x in per loop
        v_buffer := v_buffer || x.l || chr(10);
      
      END LOOP;
      if utl_file.is_open(v_archivo) then
        utl_file.fclose(v_archivo);
      end if;
      v_nom_ascii := 'DIVISAS' || to_char(fue_obt_fec_calendar(1), 'yyyymmdd') || '.txt';
      v_archivo   := utl_file.fopen(v_directorio, v_nom_ascii, 'w');
    
      utl_file.put_line(v_archivo, v_buffer);
      utl_file.fclose(v_archivo);
    end;
  end if;
end prl_gen_divisas;
/

