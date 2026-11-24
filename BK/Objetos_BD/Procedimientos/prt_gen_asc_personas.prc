create or replace procedure it.PRT_GEN_ASC_PERSONAS is
   v_sql varchar2(4000);
begin
   v_sql := 'SELECT linea_pagsue from tv_asc_personas';
   prg_gen_archivo_txt('PERS.DAT', v_sql,'N');
  
end PRT_GEN_ASC_PERSONAS;
/

