create or replace procedure it.PRM_GEN_PER_ESPANA is
   v_sql varchar2(4000);
begin
   v_sql := 'SELECT linea from mv_per_sec_espana';
   prg_gen_archivo_txt('PERSESPA.DAT', v_sql,'N');
  
end PRM_GEN_PER_ESPANA;
/

