create or replace force view it.smg_cua_armamay as
select (a.mcta || lpad(a.msubcta,6,0))cta_as,
       r.cod_rubro,
       decode(a.divisa, 0, 'GS',3,'BRL', 5,'USD', 7,'CHF', 10,'GBP',11,'AUD',
             14,'JPY',15,'ARS', 17,'EUR', 20,'UYU', 28,'CAD') cod_moneda,
       a.msuc cod_oficina,
       (decode (a.saldoactme,0, a.saldoact, a.saldoactme)* -1)sal_contable
    from simgia_armamay a,cb_rubros r
where (a.mcta || lpad(a.msubcta,6,0)) = r.cod_rub_externo
order by 2,3;

