create or replace procedure it.PRT_GEN_ASC_SOLICITUDES is
   v_sql varchar2(4000);
begin
   v_sql := 'SELECT linea_pagsue from tv_asc_solicitudes';
   prg_gen_archivo_txt('SOLICITUDES.DAT', v_sql,'N');
  
end PRT_GEN_ASC_SOLICITUDES;
/

