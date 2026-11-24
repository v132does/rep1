CREATE OR REPLACE FUNCTION IT.ful_gen_msj_swift_199(p_nro_ref_externa in varchar2, p_mto_cargo in number, p_confirmacion in varchar2)
  RETURN VARCHAR2 IS
  v_nom_archivo varchar2(100) := null;
  v_texto varchar2(3000) := null;
  cursor c_transf is
      select a.* from lc_transferencias a
       where a.nro_ref_externa = p_nro_ref_externa
       and a.fec_recepcion is not null
       and nvl(a.gpi,'N')='S';
       
  ct c_transf%rowtype;
  v_cod_swift            varchar2(20);
  v_salto                varchar2(2) := CHR(13)||CHR(10);
  v_nro_cta_corresponsal varchar2(50);
  v_cod_swi_corresponsal varchar2(12);
  v_nom_bco_cor_contra   varchar2(100);
  v_cod_swi_cor_contra   varchar2(50);
  v_cod_per_cor_contra   varchar2(20);
  v_cod_pai_cor_contra   number(5);
  v_des_pai_cor_contra   varchar2(100);
  v_cod_ciu_cor_contra   number(5);
  v_des_ciu_cor_contra   varchar2(100);
  v_det_cargo            varchar2(1):='N';
  v_uuid                 varchar2(100);
BEGIN
  pre_cam_for_numerico('.,');
  -- defino el nombre del archivo
  v_nom_archivo := 'PYCOR199'||p_nro_ref_externa||'.ICR';
  -- leo los datos del registro de la operacion
  open c_transf;
  fetch c_transf into ct;
  close c_transf;
  -- obtengo los datos del banco corresponsal
  begin
      select upper(b.cod_swift), a.nro_cuenta
        into v_cod_swi_corresponsal, v_nro_cta_corresponsal
        from ge_bancos b, cc_cta_bancarias a
       where a.cod_moneda = ct.cod_moneda
         and a.estado = 'N'
         and a.cod_modalidad = 45
         and a.cod_banco = ct.cod_bco_corresponsal
         and b.cod_banco = a.cod_banco;
  exception
      when no_data_found then
        raise_application_error(-20009,'Corresponsal inexistente');
      when too_many_rows then
        raise_application_error(-20010,'Varios Correponsales definidos');
      when others then
        raise_application_error(-20011,'Recup.Corresp.'|| sqlerrm);
  end;
  -- obtengo los datos del banco corresponsal del operante
  begin
     select a.descripcion, upper(a.cod_swift), a.cod_persona
       into v_nom_bco_cor_contra, v_cod_swi_cor_contra, v_cod_per_cor_contra
       from ge_bancos a
      where a.cod_banco = ct.cod_bco_cor_contra;
  exception
     when others then
         v_nom_bco_cor_contra := null;
         v_cod_swi_cor_contra := null;
  end;
  --wa:16/01/2015 Si es Hbank tiene otra lógica
  if ct.usu_insercion <> 'HBANK' then
    pre_obt_ciu_pais(v_cod_per_cor_contra, v_cod_pai_cor_contra, v_des_pai_cor_contra, v_cod_ciu_cor_contra, v_des_ciu_cor_contra);
  elsif  ct.usu_insercion = 'HBANK' then
    v_nom_bco_cor_contra:= ct.nom_bco_cor_contra;
    v_cod_swi_cor_contra:=ct.cod_swi_bco_contra;
    v_cod_pai_cor_contra:=ct.cod_pai_bco_contra;
    v_cod_ciu_cor_contra:=ct.cod_ciu_bco_contra;
       --Obtenemos Desc. de Pais
        begin
          select a.descripcion
             into v_des_pai_cor_contra
              from ba_paises a
               where a.cod_pais=ct.cod_pai_bco_contra;
        exception
          when no_data_found then
            v_des_pai_cor_contra:=NULL;
          when others then
            v_des_pai_cor_contra:=NULL;
        end;
        --Obtenemos Desc. de Ciudad
        begin
          select a.descripcion
             into v_des_ciu_cor_contra
              from ba_ciudades a
               where a.cod_ciudad=ct.cod_ciu_bco_contra;
        exception
          when no_data_found then
            v_des_ciu_cor_contra:=NULL;
          when others then
            v_des_ciu_cor_contra:=NULL;
        end;
  end if;
 -- obtengo el codigo de swift del banco origen --BBVAPYPAA 
  select cod_swift into v_cod_swift from ge_bancos where cod_banco = fug_obt_cod_banco;
  -- armo las partes del cuerpo del mensaje
  -- ********************************** cabecera ****************************************************
  v_texto :=          '{1:F01'||v_cod_swift||'XXX0000000000}';
  v_texto := v_texto||'{2:I199'||rpad(upper('TRCKCHZZ'/*pruebas-->'TRCKCHZ0XXX'*/),12,'X')||'N'||'}';
  --GPII Identificamos si es GPII
  if nvl(ct.gpi,'N')='S' then
    --Agregamos campos propios de GPII en Cabecera
    --v_uuid:= null;
    --v_uuid:= fug_obt_cod_uuid();
    v_texto := v_texto||'{3:{121:'||ct.codigo||'}}';
  end if;
  v_texto := v_texto||'{4:'||v_salto;
  -- ****************************** cuerpo del mensaje **********************************************
  -- 20: a definir que campo enviar
  v_texto := v_texto||':20:'||CT.NRO_REFERENCIA||v_salto;
  -- 21: (ref. of MT 103)
  v_texto := v_texto||':21:'||trim(ct.nro_ref_externa)||v_salto;
  -- 23B: Tipo de mensaje
  /* if nvl(ct.gpi,'N')='S' then
      v_texto := v_texto||':23B:CRED'||v_salto;
   else
      v_texto := v_texto||':23B:'||ct.tip_mensaje||v_salto;
   end if;*/
   -- 79: Tipo de mensaje UTC Paraguay -03:00
   v_texto := v_texto||':79://'||to_char(SYSDATE,'yymmddhhmm')||'-0300'||v_salto;
   --Siempre ACSC - Creditor has been credited, final status
   --Solo enviaremos luego de ser acreditado a la persona
   if p_confirmacion = 'S' then
      v_texto := v_texto||'//ACSP/G001'||v_salto; 
   else
      v_texto := v_texto||'//RJCT/MS03'||v_salto;
   end if;   
   --BIC 
   --En las pruebas universales solicitan el Bic de está forma para los MT199
   v_texto := v_texto||'//'||/*ct.codigo*/'BBVAPYPAXXX'||v_salto;   
--   v_texto := v_texto||'//'||CT.COD_MONEDA||CT.MONTO||v_salto; 
   v_texto := v_texto||'//'||ct.cod_moneda||trim(replace(to_char(ct.monto,'999999999999.99'),'.',','))||v_salto;
   --//currency & amount
 /*  IF nvl(p_mto_cargo,0) >0  then
      v_texto := v_texto||'//EXCH//'||ct.cod_moneda||'/'||trim(replace(nvl(p_mto_cargo,0),'.',','))||v_salto; 

   end if;*/
   -- Cantidad de Cargos de Otros Bancos
   -- //:71F:USD10,*/

   /*:79://date and time
   //ACSP/000
   //BIC (of Status Originator)
   //currency & amount
   //EXCH//USD/EUR/0,91 (if applicable)
   //:71F:USD10,*/
   v_texto := v_texto||'-}';
  -- fin de la funcion
  RETURN v_nom_archivo||'~'||v_texto;
END;
/

