CREATE OR REPLACE PROCEDURE IT.prt_ins_tar_nominadas
IS

v_can_linea  number:= 0;
v_fin_registro number:= 999999;
v_men_error    varchar2(4000);
v_error exception;
v_nom_programa varchar2(50) := 'PRT_INS_TAR_NOMINADAS';
v_nro_sob_pro_principal ta_imp_dat_embozados.nro_sob_pro_principal%type;
v_nro_pan_pro_principal ta_imp_dat_embozados.nro_pan_pro_principal%type;
v_nro_sob_pro_secundario ta_imp_dat_embozados.nro_sob_pro_secundario%type;
v_nro_pan_pro_secundario ta_imp_dat_embozados.nro_pan_pro_secundario%type;   
v_cod_persona            ba_personas.cod_persona%type;
v_nro_cuenta             ge_cuentas.nro_cuenta%type;

-- cursor de tabla temporal importado desde archivo.
cursor cu_tar_nominadas is
select
      substr(a.txt_linea, 1,6)    as secuencia,
      lpad(ltrim(substr(a.txt_linea, 7, 30), '0'), 16, '0')  as nro_sob_pro_principal,
      lpad(ltrim(substr(a.txt_linea, 37, 16), 0), 16, '0')   as nro_pan_pro_principal,
      lpad(ltrim(substr(a.txt_linea, 53, 16), '0'), 16, '0') as nro_pan_pro_secundario,
      lpad(ltrim(substr(a.txt_linea, 69, 30),'0'), 16, '0')  as nro_sob_pro_secundario,
      ''                          as cod_persona,
      ''                          as nro_cuenta,
      'A'                         as Estado
from ta_imp_dat_embozados_tmp a
where substr(a.txt_linea, 1,6) <> v_fin_registro;

begin  
  --obtengo la cantidad de registro a leer
  select count(*)
  into v_can_linea
  from ta_imp_dat_embozados_tmp a;
 
  if v_can_linea = 0 then
     v_men_error := substr('No existe registros para procesar. Verificar archivo ( T1038D.TXT ). '||sqlerrm,1,4000);
    raise v_error;
  else

    for c in cu_tar_nominadas loop                           
     
      v_nro_sob_pro_principal  := c.nro_sob_pro_principal;
      v_nro_pan_pro_principal  := c.nro_pan_pro_principal;
      v_nro_sob_pro_secundario := c.nro_sob_pro_secundario;
      v_nro_pan_pro_secundario := c.nro_pan_pro_secundario;
        
      begin
        insert into ta_imp_dat_embozados(nro_sob_pro_principal, nro_pan_pro_principal, nro_sob_pro_secundario,
        nro_pan_pro_secundario, cod_persona, nro_cuenta, estado)
                                                            
        values(v_nro_sob_pro_principal, v_nro_pan_pro_principal, v_nro_sob_pro_secundario, v_nro_pan_pro_secundario,
             v_cod_persona, v_nro_cuenta , c.Estado);
             
        commit;     
        exception
        when others then
         v_men_error := substr('Error Insert ta_imp_dat_emobozados: ' || 'Nro_Sobre: ' || c.nro_sob_pro_principal || ' ' || sqlerrm,1,4000);
         raise v_error;
      end;              
    end loop;  
  end if;
   
  exception
    when v_error then      
      prg_ins_log_programas(v_nom_programa, v_men_error, v_cod_persona, v_nro_cuenta);
      raise_application_error(-20000, v_men_error);
      
     when others then
      v_men_error := substr('Error: ' ||sqlerrm,1,4000);
      prg_ins_log_programas(v_nom_programa, v_men_error, v_cod_persona, v_nro_cuenta);
      -- lanza error en pantalla.      
      raise_application_error(-20001, v_men_error);
end;
/
