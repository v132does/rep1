create or replace package it.PAV_CUS is
 procedure pr_gen_ubi_documento(p_cod_oficina in number,
                               p_fec_vencimiento in date,
                               p_pri_apellido in varchar2,
                               p_ubicacion out varchar2,
                               p_cod_area out number,
                               p_cod_sector out number,
                               p_cod_nivel out number,
                               p_cod_hilera out number,
                               p_cod_seccion out number,
                               p_cod_orden out number);
 function fu_en_custodia(p_nro_cuenta in varchar2,
                         p_nro_cuota in number default null)
      return varchar2;
 procedure pr_ins_pag_custodia(p_cod_moneda in varchar2,
                               p_monto in number,
                               p_nro_operacion in varchar2,
                               p_fec_vencimiento in date,
                               p_cod_oficina in number,
                               p_cod_persona in varchar2,
                               p_nom_persona in varchar2,
                               p_nro_secuencia in number,
                               p_hora in varchar2);
 function fu_obt_pri_apellido (p_cod_persona in varchar2)
   return varchar2;
end PAV_CUS;
/

