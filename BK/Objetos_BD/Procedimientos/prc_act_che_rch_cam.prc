CREATE OR REPLACE PROCEDURE IT.PRC_ACT_CHE_RCH_CAM (p_cod_oficina in number,
                                                 p_cod_moneda  in varchar2) is
  v_fcdehoy       date := pag_cal.fu_obt_fec_actual(4);
  v_cdofcam       number(3) := fug_obt_ofi_camara(p_cod_oficina);

  v_cod_banco     ge_bancos.cod_banco%type := fug_obt_cod_banco;
  v_com_directa   varchar2(1) := 'N';
  v_cod_mon_local ge_par_generales.cod_mon_local%type := pag_gen.fu_obt_mon_local;
  v_cod_cau_dev   ge_causales.cod_causa%type;

  -- Cursor Principal de Cheques Rechazados a Procesar
  cursor clrch_cur is
     select c.*, c.rowid registro
       from cc_che_rechazados_tmp c
      where nvl(cod_ofi_camara, v_cdofcam) = v_cdofcam
        and estado != 'C'
        and cod_moneda = nvl(p_cod_moneda, v_cod_mon_local)
        and trunc(c.fec_insercion) = trunc(sysdate) 
      order by nro_linea, nro_cuenta;
  --

  clrch clrch_cur%rowtype;

begin

  if clrch_cur%isopen then
     close clrch_cur;
  end if;
  open clrch_cur;

  <<proceso>>  
  IF p_cod_moneda <> v_cod_mon_local THEN
     v_com_directa := 'S';
  END IF;
  loop
    fetch clrch_cur into clrch;
    exit when clrch_cur%notfound;
    
      begin
      
        select max(z.cod_causa)
          into v_cod_cau_dev
          from ge_par_causales z
         where z.parametro = 'COD_DEV_BCP' 
           and z.val_parametro =  clrch.cod_cau_dev_bcp;
       exception
         when others then
           v_cod_cau_dev := null;   
       end;    
      
      update cc_che_rechazados_tmp x
         set x.cod_cau_devolucion = v_cod_cau_dev,
             x.cod_ofi_camara = v_cdofcam,
             x.fec_proceso = v_fcdehoy,
             x.cod_bco_receptor = v_cod_banco,
             x.com_directa = v_com_directa,
             x.nro_cuenta = fuc_obt_cta_remitidos(clrch.nro_cheque, clrch.cod_bco_emisor, v_cdofcam, clrch.cod_moneda) 
        where x.rowid = clrch.registro;

  end loop;

  close clrch_cur;

end prc_act_che_rch_cam;
/

